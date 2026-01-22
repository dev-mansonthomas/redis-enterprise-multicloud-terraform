# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

###########################################################
# Local variables for scripts path
locals {
  scripts_path = "${path.module}/../../common/bastion"
}

# Create public IP for bastion node
resource "azurerm_public_ip" "client-public-ip" {
    name                         = "${var.name}-client-public-ip"
    location                     = var.region
    resource_group_name          = var.resource_group
    allocation_method            = "Static"
    sku                          = "Standard"
    zones                        = [var.availability_zone]

    tags = merge(var.resource_tags, {
        environment = "${var.name}"
    })
}

# Create network interface for client node
resource "azurerm_network_interface" "client-nic" {
    name                      = "${var.name}-client-nic"
    location                  = var.region
    resource_group_name       = var.resource_group

    ip_configuration {
        name                          = "${var.name}-client-nic-configuration"
        subnet_id                     = var.subnet
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.client-public-ip.id
    }

    tags = merge(var.resource_tags, {
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
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = var.resource_group
    location                    = var.region
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = merge(var.resource_tags, {
        environment = "${var.name}"
    })
}

# Create client node
resource "azurerm_linux_virtual_machine" "client" {
    name                  = "${var.name}-client"
    location              = var.region
    resource_group_name   = var.resource_group
    network_interface_ids = [azurerm_network_interface.client-nic.id]
    size                  = var.machine_type
    zone                  = var.availability_zone

    os_disk {
      name                 = "${var.name}-client_boot_disk"
      caching              = "ReadWrite"
      storage_account_type = "${var.boot_disk_type}"
      disk_size_gb         = var.boot_disk_size
    }

    source_image_reference {
      publisher = split(":", var.machine_image)[0]
      offer     = split(":", var.machine_image)[1]
      sku       = split(":", var.machine_image)[2]
      version   = split(":", var.machine_image)[3]
    }

    computer_name  = "${var.name}-client"
    admin_username = var.ssh_user
    disable_password_authentication = true

    admin_ssh_key {
        username       = var.ssh_user
        public_key     = file(var.ssh_public_key)
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = merge(var.resource_tags, {
        environment = "${var.name}"
    })

    # Connection configuration for provisioners
    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(replace(var.ssh_public_key, ".pub", ""))
      host        = azurerm_public_ip.client-public-ip.ip_address
      timeout     = "10m"
    }

    # Copy installation script to the instance
    provisioner "file" {
      content = templatefile("${local.scripts_path}/prepare_client.sh", {
        ssh_user           = var.ssh_user
        cluster_dns        = var.cluster_dns
        memtier_package    = var.memtier_package
        prometheus_package = var.prometheus_package
        grafana_version    = var.grafana_version
        java_version       = var.java_version
      })
      destination = "/home/${var.ssh_user}/prepare_client.sh"
    }

    # Execute installation script
    provisioner "remote-exec" {
      inline = [
        "chmod +x /home/${var.ssh_user}/prepare_client.sh",
        "echo '=== Starting Bastion Preparation ==='",
        "sudo /home/${var.ssh_user}/prepare_client.sh",
        "echo '=== Bastion Preparation Complete ==='"
      ]
    }
}