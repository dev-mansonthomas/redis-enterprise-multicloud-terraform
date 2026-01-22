terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
    }
  }
}

###########################################################
# Local variables for scripts path
locals {
  scripts_path = "${path.module}/../../common/bastion"
}

resource "google_compute_address" "bastion-ip-address" {
  name  = "${var.name}-bastion-ip-address"
}

resource "google_compute_instance" "bastion" {
  name         = "${var.name}-bastion"
  machine_type = var.machine_type
  zone         = var.availability_zone
  labels       = var.resource_tags

  boot_disk {
    initialize_params {
      image = var.machine_image
      size  = var.boot_disk_size
    }
  }

  network_interface {
    subnetwork = var.subnet

    access_config {
      nat_ip  = google_compute_address.bastion-ip-address.address
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
    private_key = file(replace(var.ssh_public_key, ".pub", ""))
    host        = google_compute_address.bastion-ip-address.address
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