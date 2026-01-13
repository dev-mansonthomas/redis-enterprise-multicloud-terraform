# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

###########################################################
# Local variables for scripts path
locals {
  scripts_path = "${path.module}/../../common/scripts"
}

###########################################################
# Create public IPs
resource "azurerm_public_ip" "public-ips" {
  count               = var.private_conf ? 0 : var.worker_count
  name                = "${var.name}-public-IP-${count.index}"
  location            = var.region
  resource_group_name = var.resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [sort(var.availability_zones)[count.index % length(var.availability_zones)]]
}

###########################################################
# Create network interface for Redis nodes
resource "azurerm_network_interface" "nic" {
  name                = "${var.name}-node-${count.index}-nic"
  location            = var.region
  resource_group_name = var.resource_group
  depends_on          = [azurerm_public_ip.public-ips]
  count               = var.worker_count

  ip_configuration {
    name                          = "${var.name}-node-nic-${count.index}-configuration"
    subnet_id                     = var.subnets[count.index % length(var.subnets)]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.private_conf ? null : azurerm_public_ip.public-ips[count.index].id
  }

  tags = merge("${var.resource_tags}", {
    environment = "${var.name}"
  })
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = var.resource_group
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = var.resource_group
  location                 = var.region
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = merge("${var.resource_tags}", {
    environment = "${var.name}"
  })
}

###########################################################
# Create Redis nodes
resource "azurerm_linux_virtual_machine" "nodes" {
  name                  = "${var.name}-node-${count.index}"
  location              = var.region
  resource_group_name   = var.resource_group
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
  size                  = var.machine_type
  zone                  = sort(var.availability_zones)[count.index % length(var.availability_zones)]
  count                 = var.worker_count

  os_disk {
    name                 = "${var.name}-node-${count.index}_boot_disk"
    caching              = "ReadWrite"
    storage_account_type = var.boot_disk_type
    disk_size_gb         = var.boot_disk_size
  }

  source_image_reference {
    publisher = split(":", var.machine_image)[0]
    offer     = split(":", var.machine_image)[1]
    sku       = split(":", var.machine_image)[2]
    version   = split(":", var.machine_image)[3]
  }

  computer_name                   = "${var.name}-node-${count.index}"
  admin_username                  = var.ssh_user
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.ssh_user
    public_key = file(var.ssh_public_key)
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
  }

  tags = merge(var.resource_tags, {
    environment = var.name
  })

  # Connection configuration for provisioners
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key)
    host        = var.private_conf ? azurerm_network_interface.nic[count.index].private_ip_address : azurerm_public_ip.public-ips[count.index].ip_address
    timeout     = "10m"
  }

  # Copy installation scripts to the instance
  provisioner "file" {
    source      = local.scripts_path
    destination = "/home/${var.ssh_user}/redis-scripts"
  }

  # Execute installation scripts
  # IMPORTANT: All commands must be in a single script to preserve environment variables
  provisioner "remote-exec" {
    inline = [
      <<-EOT
      #!/bin/bash
      set -e

      chmod +x /home/${var.ssh_user}/redis-scripts/*.sh
      echo '=== Starting Redis Enterprise Installation - Node ${count.index + 1} ==='

      # Set environment variables (persist across all steps)
      export SSH_USER='${var.ssh_user}'
      export REDIS_DISTRO='${var.redis_distro}'
      export FLASH_ENABLED='${var.flash_enabled}'

      # Step 1: Prepare system
      echo '>>> Step 1: Preparing system...'
      sudo -E /home/${var.ssh_user}/redis-scripts/01_prepare_system.sh

      # Step 2: Install Redis Enterprise
      echo '>>> Step 2: Installing Redis Enterprise...'
      sudo -E /home/${var.ssh_user}/redis-scripts/02_install_redis_enterprise.sh

      # Step 3: Create or join cluster
      echo '>>> Step 3: Configuring cluster...'
      export EXTERNAL_ADDR=$(curl -s ifconfig.me/ip)
      if [ '${var.private_conf}' = 'true' ]; then EXTERNAL_ADDR='none'; fi
      export MODE='${count.index == 0 ? "init" : "join"}'
      export MASTER_IP='${count.index == 0 ? "" : azurerm_network_interface.nic[0].private_ip_address}'
      sudo -E /home/${var.ssh_user}/redis-scripts/03_create_or_join_cluster.sh '${var.cluster_dns}' '${var.redis_user}' '${var.redis_password}' "$MODE" "$EXTERNAL_ADDR" '${sort(var.availability_zones)[count.index % length(var.availability_zones)]}' '${count.index + 1}' "$MASTER_IP"

      # Store node info
      echo '${count.index + 1}' | sudo tee /home/${var.ssh_user}/node_index.terraform
      sudo chown ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/node_index.terraform

      echo '=== Redis Enterprise Installation Complete - Node ${count.index + 1} ==='
      EOT
    ]
  }
}
###########################################################
# Data Disks for Redis on Flash (RAID 0)
# For Lsv3 instances with built-in NVMe, set data_disk_count = 0
# Otherwise, creates managed disks for high-performance storage
###########################################################

locals {
  # Create a flat list of all disk configurations
  data_disks = var.flash_enabled && var.data_disk_count > 0 ? flatten([
    for node_idx in range(var.worker_count) : [
      for disk_idx in range(var.data_disk_count) : {
        node_idx  = node_idx
        disk_idx  = disk_idx
        unique_id = "${node_idx}-${disk_idx}"
        zone      = sort(var.availability_zones)[node_idx % length(var.availability_zones)]
      }
    ]
  ]) : []
}

resource "azurerm_managed_disk" "data_disk" {
  for_each = { for disk in local.data_disks : disk.unique_id => disk }

  name                 = "${var.name}-data-${each.value.node_idx}-${each.value.disk_idx}"
  location             = var.region
  resource_group_name  = var.resource_group
  storage_account_type = var.data_disk_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size
  zone                 = each.value.zone

  # PremiumV2_LRS and UltraSSD_LRS support IOPS and throughput provisioning
  disk_iops_read_write = contains(["PremiumV2_LRS", "UltraSSD_LRS"], var.data_disk_type) ? var.data_disk_iops : null
  disk_mbps_read_write = contains(["PremiumV2_LRS", "UltraSSD_LRS"], var.data_disk_type) ? var.data_disk_throughput : null

  tags = merge(var.resource_tags, {
    Name = "${var.name}-data-${each.value.node_idx}-${each.value.disk_idx}"
    Role = "redis-flash-data"
  })
}

resource "azurerm_virtual_machine_data_disk_attachment" "data_disk" {
  for_each = { for disk in local.data_disks : disk.unique_id => disk }

  managed_disk_id    = azurerm_managed_disk.data_disk[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.nodes[each.value.node_idx].id
  lun                = each.value.disk_idx
  caching            = "None"
}