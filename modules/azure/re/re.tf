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
  # Normalize region name for rack_id (remove spaces, lowercase)
  # Redis Enterprise requires rack_id to start with a letter
  # Azure zones are just numbers (1, 2, 3), so we prefix with region name
  region_normalized = lower(replace(var.region, " ", "-"))
}

###########################################################
# Master node public IP
resource "azurerm_public_ip" "master-ip" {
  count               = var.private_conf ? 0 : 1
  name                = "${var.name}-master-public-IP"
  location            = var.region
  resource_group_name = var.resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [sort(var.availability_zones)[0]]
}

# Worker nodes public IPs
resource "azurerm_public_ip" "worker-ips" {
  count               = var.private_conf ? 0 : (var.worker_count > 1 ? var.worker_count - 1 : 0)
  name                = "${var.name}-worker-${count.index}-public-IP"
  location            = var.region
  resource_group_name = var.resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [sort(var.availability_zones)[(count.index + 1) % length(var.availability_zones)]]
}

###########################################################
# Master node network interface
resource "azurerm_network_interface" "master-nic" {
  name                = "${var.name}-master-nic"
  location            = var.region
  resource_group_name = var.resource_group
  depends_on          = [azurerm_public_ip.master-ip]

  ip_configuration {
    name                          = "${var.name}-master-nic-configuration"
    subnet_id                     = var.subnets[0]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.private_conf ? null : azurerm_public_ip.master-ip[0].id
  }

  tags = merge("${var.resource_tags}", {
    environment = "${var.name}"
  })
}

# Worker nodes network interfaces
resource "azurerm_network_interface" "worker-nic" {
  count               = var.worker_count > 1 ? var.worker_count - 1 : 0
  name                = "${var.name}-worker-${count.index}-nic"
  location            = var.region
  resource_group_name = var.resource_group
  depends_on          = [azurerm_public_ip.worker-ips]

  ip_configuration {
    name                          = "${var.name}-worker-nic-${count.index}-configuration"
    subnet_id                     = var.subnets[(count.index + 1) % length(var.subnets)]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.private_conf ? null : azurerm_public_ip.worker-ips[count.index].id
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
# Master node (node-0)
resource "azurerm_linux_virtual_machine" "cluster_master" {
  name                  = "${var.name}-node-0"
  location              = var.region
  resource_group_name   = var.resource_group
  network_interface_ids = [azurerm_network_interface.master-nic.id]
  size                  = var.machine_type
  zone                  = sort(var.availability_zones)[0]

  os_disk {
    name                 = "${var.name}-node-0_boot_disk"
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

  computer_name                   = "${var.name}-node-0"
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

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key)
    host        = var.private_conf ? azurerm_network_interface.master-nic.private_ip_address : azurerm_public_ip.master-ip[0].ip_address
    timeout     = "10m"
  }

  provisioner "file" {
    source      = local.scripts_path
    destination = "/home/${var.ssh_user}/redis-scripts"
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
      #!/bin/bash
      set -e

      chmod +x /home/${var.ssh_user}/redis-scripts/*.sh
      echo '=== Starting Redis Enterprise Installation - Master Node ==='

      export SSH_USER='${var.ssh_user}'
      export REDIS_DISTRO='${var.redis_distro}'
      export FLASH_ENABLED='${var.flash_enabled}'

      echo '>>> Step 1: Preparing system...'
      sudo -E /home/${var.ssh_user}/redis-scripts/01_prepare_system.sh

      echo '>>> Step 2: Installing Redis Enterprise...'
      sudo -E /home/${var.ssh_user}/redis-scripts/02_install_redis_enterprise.sh

      echo '>>> Step 3: Creating cluster...'
      export EXTERNAL_ADDR=$(curl -s ifconfig.me/ip)
      if [ '${var.private_conf}' = 'true' ]; then EXTERNAL_ADDR='none'; fi
      # Rack ID must start with a letter (RE 8+ requirement), so we prefix Azure zone numbers with region name
      sudo -E /home/${var.ssh_user}/redis-scripts/03_create_or_join_cluster.sh '${var.cluster_dns}' '${var.redis_user}' '${var.redis_password}' 'init' "$EXTERNAL_ADDR" '${local.region_normalized}-zone${sort(var.availability_zones)[0]}' '1' ''

      echo '1' | sudo tee /home/${var.ssh_user}/node_index.terraform
      sudo chown ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/node_index.terraform

      echo '=== Redis Enterprise Installation Complete - Master Node ==='
      EOT
    ]
  }
}

###########################################################
# Worker nodes (node-1, node-2, ...)
resource "azurerm_linux_virtual_machine" "nodes" {
  count                 = var.worker_count > 1 ? var.worker_count - 1 : 0
  name                  = "${var.name}-node-${count.index + 1}"
  location              = var.region
  resource_group_name   = var.resource_group
  network_interface_ids = [azurerm_network_interface.worker-nic[count.index].id]
  size                  = var.machine_type
  zone                  = sort(var.availability_zones)[(count.index + 1) % length(var.availability_zones)]

  # Ensure master is created first
  depends_on = [azurerm_linux_virtual_machine.cluster_master]

  os_disk {
    name                 = "${var.name}-node-${count.index + 1}_boot_disk"
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

  computer_name                   = "${var.name}-node-${count.index + 1}"
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

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key)
    host        = var.private_conf ? azurerm_network_interface.worker-nic[count.index].private_ip_address : azurerm_public_ip.worker-ips[count.index].ip_address
    timeout     = "10m"
  }

  provisioner "file" {
    source      = local.scripts_path
    destination = "/home/${var.ssh_user}/redis-scripts"
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
      #!/bin/bash
      set -e

      chmod +x /home/${var.ssh_user}/redis-scripts/*.sh
      echo '=== Starting Redis Enterprise Installation - Worker Node ${count.index + 2} ==='

      export SSH_USER='${var.ssh_user}'
      export REDIS_DISTRO='${var.redis_distro}'
      export FLASH_ENABLED='${var.flash_enabled}'

      echo '>>> Step 1: Preparing system...'
      sudo -E /home/${var.ssh_user}/redis-scripts/01_prepare_system.sh

      echo '>>> Step 2: Installing Redis Enterprise...'
      sudo -E /home/${var.ssh_user}/redis-scripts/02_install_redis_enterprise.sh

      echo '>>> Step 3: Joining cluster...'
      export EXTERNAL_ADDR=$(curl -s ifconfig.me/ip)
      if [ '${var.private_conf}' = 'true' ]; then EXTERNAL_ADDR='none'; fi
      # Rack ID must start with a letter (RE 8+ requirement), so we prefix Azure zone numbers with region name
      sudo -E /home/${var.ssh_user}/redis-scripts/03_create_or_join_cluster.sh '${var.cluster_dns}' '${var.redis_user}' '${var.redis_password}' 'join' "$EXTERNAL_ADDR" '${local.region_normalized}-zone${sort(var.availability_zones)[(count.index + 1) % length(var.availability_zones)]}' '${count.index + 2}' '${azurerm_network_interface.master-nic.private_ip_address}'

      echo '${count.index + 2}' | sudo tee /home/${var.ssh_user}/node_index.terraform
      sudo chown ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/node_index.terraform

      echo '=== Redis Enterprise Installation Complete - Worker Node ${count.index + 2} ==='
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
  # Master disk configurations (node 0)
  master_disks = var.flash_enabled && var.data_disk_count > 0 ? [
    for disk_idx in range(var.data_disk_count) : {
      disk_idx  = disk_idx
      unique_id = "master-${disk_idx}"
      zone      = sort(var.availability_zones)[0]
    }
  ] : []

  # Worker disk configurations (node 1+)
  worker_disks = var.flash_enabled && var.data_disk_count > 0 && var.worker_count > 1 ? flatten([
    for node_idx in range(var.worker_count - 1) : [
      for disk_idx in range(var.data_disk_count) : {
        node_idx  = node_idx
        disk_idx  = disk_idx
        unique_id = "worker-${node_idx}-${disk_idx}"
        zone      = sort(var.availability_zones)[(node_idx + 1) % length(var.availability_zones)]
      }
    ]
  ]) : []
}

# Master data disks
resource "azurerm_managed_disk" "master_data_disk" {
  for_each = { for disk in local.master_disks : disk.unique_id => disk }

  name                 = "${var.name}-data-0-${each.value.disk_idx}"
  location             = var.region
  resource_group_name  = var.resource_group
  storage_account_type = var.data_disk_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size
  zone                 = each.value.zone

  disk_iops_read_write = contains(["PremiumV2_LRS", "UltraSSD_LRS"], var.data_disk_type) ? var.data_disk_iops : null
  disk_mbps_read_write = contains(["PremiumV2_LRS", "UltraSSD_LRS"], var.data_disk_type) ? var.data_disk_throughput : null

  tags = merge(var.resource_tags, {
    Name = "${var.name}-data-0-${each.value.disk_idx}"
    Role = "redis-flash-data"
  })
}

resource "azurerm_virtual_machine_data_disk_attachment" "master_data_disk" {
  for_each = { for disk in local.master_disks : disk.unique_id => disk }

  managed_disk_id    = azurerm_managed_disk.master_data_disk[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.cluster_master.id
  lun                = each.value.disk_idx
  caching            = "None"
}

# Worker data disks
resource "azurerm_managed_disk" "worker_data_disk" {
  for_each = { for disk in local.worker_disks : disk.unique_id => disk }

  name                 = "${var.name}-data-${each.value.node_idx + 1}-${each.value.disk_idx}"
  location             = var.region
  resource_group_name  = var.resource_group
  storage_account_type = var.data_disk_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size
  zone                 = each.value.zone

  disk_iops_read_write = contains(["PremiumV2_LRS", "UltraSSD_LRS"], var.data_disk_type) ? var.data_disk_iops : null
  disk_mbps_read_write = contains(["PremiumV2_LRS", "UltraSSD_LRS"], var.data_disk_type) ? var.data_disk_throughput : null

  tags = merge(var.resource_tags, {
    Name = "${var.name}-data-${each.value.node_idx + 1}-${each.value.disk_idx}"
    Role = "redis-flash-data"
  })
}

resource "azurerm_virtual_machine_data_disk_attachment" "worker_data_disk" {
  for_each = { for disk in local.worker_disks : disk.unique_id => disk }

  managed_disk_id    = azurerm_managed_disk.worker_data_disk[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.nodes[each.value.node_idx].id
  lun                = each.value.disk_idx
  caching            = "None"
}