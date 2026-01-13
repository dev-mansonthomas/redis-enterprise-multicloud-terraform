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
  scripts_path = "${path.module}/../../common/scripts"
}

###########################################################
# Network Interface
resource "aws_network_interface" "cluster_nic" {
  subnet_id       = var.subnets[count.index % length(var.availability_zones)].id
  security_groups = var.security_groups
  count           = var.worker_count

  tags = merge("${var.resource_tags}", {
    Name = "${var.name}-cluster-nic-${count.index}"
  })
}

###########################################################
# EC2
resource "aws_instance" "node" {
  ami               = var.machine_image
  instance_type     = var.machine_type
  availability_zone = sort(var.availability_zones)[count.index % length(var.availability_zones)]
  key_name          = var.ssh_key_name
  count             = var.worker_count

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.cluster_nic[count.index].id
  }

  root_block_device {
    volume_size           = var.boot_disk_size
    volume_type           = var.boot_disk_type
    delete_on_termination = true
  }

  # Minimal user_data to setup SSH key and wait for cloud-init
  user_data = <<-USERDATA
#!/bin/bash
set -x
exec > >(tee /var/log/user-data.log) 2>&1
echo "$(date) - Waiting for cloud-init to complete..."
while [ ! -d /home/${var.ssh_user} ]; do
  sleep 5
done
echo "${file(var.ssh_public_key)}" >> /home/${var.ssh_user}/.ssh/authorized_keys
chown ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/.ssh/authorized_keys
echo "$(date) - SSH key configured, ready for provisioners"
USERDATA

  tags = merge("${var.resource_tags}", {
    Name = "${var.name}-node-${count.index}"
  })

  # Connection configuration for provisioners
  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key)
    host        = self.public_ip
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
      echo '=== Starting Redis Enterprise Installation ==='

      # Set environment variables (persist across all steps)
      export SSH_USER='${var.ssh_user}'
      export REDIS_DISTRO='${var.redis_distro}'
      export FLASH_ENABLED='${var.flash_enabled}'
      export NODE_ID='${count.index + 1}'
      export CLUSTER_DNS='${var.cluster_dns}'
      export ADMIN_USER='${var.redis_user}'
      export ADMIN_PASSWORD='${var.redis_password}'
      export ZONE='${sort(var.availability_zones)[count.index % length(var.availability_zones)]}'
      export PRIVATE_CONF='${var.private_conf}'
      export MASTER_IP='${count.index == 0 ? "" : aws_network_interface.cluster_nic[0].private_ip}'
      export RACK_AWARE='${var.rack_aware}'

      # Step 1: Prepare system
      echo '>>> Step 1: Preparing system...'
      DEBIAN_FRONTEND=noninteractive sudo -E /home/${var.ssh_user}/redis-scripts/01_prepare_system.sh

      # Step 2: Install Redis Enterprise
      echo '>>> Step 2: Installing Redis Enterprise...'
      DEBIAN_FRONTEND=noninteractive  sudo -E /home/${var.ssh_user}/redis-scripts/02_install_redis_enterprise.sh

      # Step 3: Create or join cluster
      echo '>>> Step 3: Configuring cluster...'
      export EXTERNAL_ADDR=$(curl -s ifconfig.me/ip)
      if [ '${var.private_conf}' = 'true' ]; then EXTERNAL_ADDR='none'; fi
      export MODE='${count.index == 0 ? "init" : "join"}'
      DEBIAN_FRONTEND=noninteractive  sudo -E /home/${var.ssh_user}/redis-scripts/03_create_or_join_cluster.sh "$CLUSTER_DNS" "$ADMIN_USER" "$ADMIN_PASSWORD" "$MODE" "$EXTERNAL_ADDR" "$ZONE" "$NODE_ID" "$MASTER_IP"

      # Store node info
      echo '${count.index + 1}' | sudo tee /home/${var.ssh_user}/node_index.terraform
      sudo chown ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/node_index.terraform

      echo '=== Redis Enterprise Installation Complete ==='
      EOT
    ]
  }
}

