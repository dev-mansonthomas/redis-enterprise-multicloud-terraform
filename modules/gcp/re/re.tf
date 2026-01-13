terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

###########################################################
# Local variables for scripts path
locals {
  scripts_path = "${path.module}/../../common/scripts"
}

###########################################################
# Master node (node-0)
resource "google_compute_instance" "cluster_master" {
  name           = "${var.name}-node-0"
  machine_type   = var.machine_type
  zone           = var.availability_zones[0]
  can_ip_forward = true
  labels         = var.resource_tags

  boot_disk {
    initialize_params {
      image = var.machine_image
      size  = var.boot_disk_size
      type  = var.boot_disk_type
    }
  }

  // Redis on Flash with Local SSDs (375GB each, RAID 0 for combined storage)
  dynamic "scratch_disk" {
    for_each = var.flash_enabled ? range(var.local_ssd_count) : []
    content {
      interface = "NVME"
    }
  }

  network_interface {
    subnetwork = var.subnets[0].id

    dynamic "access_config" {
      for_each = var.private_conf ? [] : [1]
      content {
        // ephemeral public IP if var.private_conf is false
      }
    }
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  metadata = {
    sshKeys = "${var.ssh_user}:${file(var.ssh_public_key)}"
  }

  # Connection configuration for provisioners
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key)
    host        = self.network_interface[0].access_config[0].nat_ip
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
      echo '=== Starting Redis Enterprise Installation - Master Node ==='

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

      # Step 3: Create cluster
      echo '>>> Step 3: Creating cluster...'
      export EXTERNAL_ADDR=$(curl -s ifconfig.me/ip)
      if [ '${var.private_conf}' = 'true' ]; then EXTERNAL_ADDR='none'; fi
      sudo -E /home/${var.ssh_user}/redis-scripts/03_create_or_join_cluster.sh '${var.cluster_dns}' '${var.redis_user}' '${var.redis_password}' 'init' "$EXTERNAL_ADDR" '${var.availability_zones[0]}' '1' ''

      # Store node info
      echo '1' | sudo tee /home/${var.ssh_user}/node_index.terraform
      sudo chown ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/node_index.terraform

      echo '=== Redis Enterprise Installation Complete - Master Node ==='
      EOT
    ]
  }
}

###########################################################
# Worker nodes (node-1, node-2, ...)
resource "google_compute_instance" "nodes" {
  count          = (var.worker_count > 1) ? var.worker_count - 1 : 0
  name           = "${var.name}-node-${count.index + 1}"
  machine_type   = var.machine_type
  zone           = var.availability_zones[(count.index + 1) % length(var.availability_zones)]
  can_ip_forward = true
  labels         = var.resource_tags

  # Ensure master is created first
  depends_on = [google_compute_instance.cluster_master]

  boot_disk {
    initialize_params {
      image = var.machine_image
      size  = var.boot_disk_size
      type  = var.boot_disk_type
    }
  }

  // Redis on Flash with Local SSDs (375GB each, RAID 0 for combined storage)
  dynamic "scratch_disk" {
    for_each = var.flash_enabled ? range(var.local_ssd_count) : []
    content {
      interface = "NVME"
    }
  }

  network_interface {
    subnetwork = var.subnets[(count.index + 1) % length(var.availability_zones)].id

    dynamic "access_config" {
      for_each = var.private_conf ? [] : [1]
      content {
        // ephemeral public IP if var.private_conf is false
      }
    }
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  metadata = {
    sshKeys = "${var.ssh_user}:${file(var.ssh_public_key)}"
  }

  # Connection configuration for provisioners
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key)
    host        = self.network_interface[0].access_config[0].nat_ip
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
      echo '=== Starting Redis Enterprise Installation - Worker Node ${count.index + 2} ==='

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

      # Step 3: Join cluster
      echo '>>> Step 3: Joining cluster...'
      export EXTERNAL_ADDR=$(curl -s ifconfig.me/ip)
      if [ '${var.private_conf}' = 'true' ]; then EXTERNAL_ADDR='none'; fi
      sudo -E /home/${var.ssh_user}/redis-scripts/03_create_or_join_cluster.sh '${var.cluster_dns}' '${var.redis_user}' '${var.redis_password}' 'join' "$EXTERNAL_ADDR" '${var.availability_zones[(count.index + 1) % length(var.availability_zones)]}' '${count.index + 2}' '${google_compute_instance.cluster_master.network_interface.0.network_ip}'

      # Store node info
      echo '${count.index + 2}' | sudo tee /home/${var.ssh_user}/node_index.terraform
      sudo chown ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/node_index.terraform

      echo '=== Redis Enterprise Installation Complete - Worker Node ${count.index + 2} ==='
      EOT
    ]
  }
}