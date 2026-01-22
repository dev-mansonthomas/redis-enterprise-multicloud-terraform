terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

###########################################################
# Local variables for scripts path
locals {
  scripts_path = "${path.module}/../../common/bastion"
}

############################################################
# Network Interface

resource "aws_network_interface" "nic" {
  subnet_id       = var.subnet
  security_groups = var.security_groups

  tags = merge("${var.resource_tags}",{
    Name = "${var.name}-client-nic"
  })
}


# Elastic IP to the Network Interface
resource "aws_eip" "eip" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.nic.id
  associate_with_private_ip = aws_network_interface.nic.private_ip
  depends_on                = [aws_instance.bastion]

  tags = merge("${var.resource_tags}",{
    Name = "${var.name}-client-eip"
  })
}


############################################################
# EC2

resource "aws_instance" "bastion" {
  ami               = var.machine_image
  instance_type     = var.machine_type
  availability_zone = var.availability_zone
  key_name          = var.ssh_key_name

  tags = merge("${var.resource_tags}",{
    Name = "${var.name}-client"
  })

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.nic.id
  }

  root_block_device {
    volume_size           = var.boot_disk_size
    volume_type           = var.boot_disk_type
    delete_on_termination = true
  }

}

############################################################
# Provisioners using null_resource to run after EIP is created
resource "null_resource" "bastion_provisioner" {
  depends_on = [aws_eip.eip]

  # Connection configuration for provisioners
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(replace(var.ssh_public_key, ".pub", ""))
    host        = aws_eip.eip.public_ip
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