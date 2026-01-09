terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

###########################################################
# Network Interface
resource "aws_network_interface" "cluster_nic" {
  subnet_id       = var.subnets[count.index % length(var.availability_zones)].id
  security_groups = var.security_groups
  count           = var.worker_count

  tags = merge("${var.resource_tags}",{
    Name = "${var.name}-cluster-nic-${count.index}"
  })
}

# Elastic IP to the Network Interface
#resource "aws_eip" "eip" {
#  vpc                       = true
#  count                     = var.worker_count
#  network_interface         = aws_network_interface.cluster_nic[count.index].id
#  associate_with_private_ip = aws_network_interface.cluster_nic[count.index].private_ip
#  depends_on                = [aws_instance.node]
#
#  tags = merge("${var.resource_tags}",{
#    Name = "${var.name}-cluster-eip-${count.index}"
#  })
#}

###########################################################
# EC2
resource "aws_instance" "node" {
  ami = var.machine_image 
  instance_type = var.machine_type
  availability_zone = sort(var.availability_zones)[count.index % length(var.availability_zones)]
  key_name = var.ssh_key_name
  count    = var.worker_count

  network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.cluster_nic[count.index].id
  }

  root_block_device {
    volume_size           = var.boot_disk_size
    volume_type           = var.boot_disk_type
    delete_on_termination = true
  }

  user_data = <<-USERDATA
#!/bin/bash
set -x  # Debug mode - log all commands
exec > >(tee /var/log/user-data.log) 2>&1

echo "$(date) - Starting user_data script"

# Wait for cloud-init to create the user
while [ ! -d /home/${var.ssh_user} ]; do
  echo "Waiting for /home/${var.ssh_user} to be created..."
  sleep 5
done

echo "$(date) - CREATING SSH key" >> /home/${var.ssh_user}/install_redis.log
sudo -u ${var.ssh_user} bash -c 'echo "${file(var.ssh_public_key)}" >> ~/.ssh/authorized_keys'

echo "$(date) - PREPARING machine node" >> /home/${var.ssh_user}/install_redis.log
apt-get -y update
apt-get -y install vim iotop iputils-ping curl jq netcat dnsutils

# --- Configure umask for root & ubuntu ---
echo "umask 0022" | tee -a /root/.profile > /dev/null
echo "umask 0022" >> ~/.profile
umask 0022

export DEBIAN_FRONTEND=noninteractive
export TZ="UTC"
apt-get install -y tzdata
ln -fs /usr/share/zoneinfo/Europe/Paris /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata

# cloud instance have no swap anyway
#swapoff -a
#sed -i.bak '/ swap / s/^(.*)$/#1/g' /etc/fstab
echo 'DNSStubListener=no' | tee -a /etc/systemd/resolved.conf
mv /etc/resolv.conf /etc/resolv.conf.orig
ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
service systemd-resolved restart
sysctl -w net.ipv4.ip_local_port_range="40000 65535"
echo "net.ipv4.ip_local_port_range = 40000 65535" >> /etc/sysctl.conf

echo "$(date) - PREPARE done" >> /home/${var.ssh_user}/install_redis.log

################
# RS

echo "$(date) - INSTALLING Redis Enterprise" >> /home/${var.ssh_user}/install_redis.log

mkdir -p /home/${var.ssh_user}/install

echo "$(date) - DOWNLOADING Redis Enterprise from : ${var.redis_distro}" >> /home/${var.ssh_user}/install_redis.log
wget "${var.redis_distro}" -P /home/${var.ssh_user}/install
tar xvf /home/${var.ssh_user}/install/redislabs*.tar -C /home/${var.ssh_user}/install

echo "$(date) - INSTALLING Redis Enterprise - silent installation" >> /home/${var.ssh_user}/install_redis.log

# Prepare environment for clean installation
export DEBIAN_FRONTEND=noninteractive

# Create /etc/rc.local to avoid "sed: can't read /etc/rc.local" warning (Ubuntu 22.04+ doesn't have it)
if [ ! -f /etc/rc.local ]; then
  echo '#!/bin/bash' > /etc/rc.local
  echo 'exit 0' >> /etc/rc.local
  chmod +x /etc/rc.local
fi

cd /home/${var.ssh_user}/install
sudo -E /home/${var.ssh_user}/install/install.sh -y 2>&1 >> /home/${var.ssh_user}/install_rs.log
sudo adduser ${var.ssh_user} redislabs

echo "$(date) - INSTALL done" >> /home/${var.ssh_user}/install_redis.log

################
# Wait for Redis Enterprise services to be ready
echo "$(date) - Waiting for Redis Enterprise services to start..." >> /home/${var.ssh_user}/install_redis.log

# Wait for supervisorctl to be available and services to be running
max_wait=120
waited=0
while [ $waited -lt $max_wait ]; do
  if sudo /opt/redislabs/bin/supervisorctl status 2>/dev/null | grep -q "RUNNING"; then
    echo "$(date) - Redis Enterprise services are running" >> /home/${var.ssh_user}/install_redis.log
    break
  fi
  echo "Waiting for services... ($waited/$max_wait seconds)" >> /home/${var.ssh_user}/install_redis.log
  sleep 5
  waited=$((waited + 5))
done

# Additional wait to ensure all services are fully initialized
sleep 10

################
# NODE

node_external_addr=$(curl -s ifconfig.me/ip)
echo "Node ${count.index + 1} : $node_external_addr" >> /home/${var.ssh_user}/install_redis.log
rack_aware=${var.rack_aware}
private_conf=${var.private_conf}

if [ ${count.index + 1} -eq 1 ]; then
  echo "$(date) - Creating cluster..." >> /home/${var.ssh_user}/install_redis.log
  command="/opt/redislabs/bin/rladmin cluster create name ${var.cluster_dns} username ${var.redis_user} password '${var.redis_password}' flash_enabled"

  if $rack_aware ; then
    command="$command rack_aware rack_id '${sort(var.availability_zones)[count.index % length(var.availability_zones)]}'"
  fi

  if ! $private_conf; then
    command="$command external_addr $node_external_addr"
  fi
  echo "Command: $command" >> /home/${var.ssh_user}/install_redis.log

  # Execute and capture both stdout and stderr, also check exit code
  if sudo bash -c "$command" >> /home/${var.ssh_user}/install_redis.log 2>&1; then
    echo "$(date) - Cluster created successfully" >> /home/${var.ssh_user}/install_redis.log
  else
    echo "$(date) - ERROR: Cluster creation failed with exit code $?" >> /home/${var.ssh_user}/install_redis.log
  fi
else
  echo "$(date) - Joining cluster..." >> /home/${var.ssh_user}/install_redis.log
  command="/opt/redislabs/bin/rladmin cluster join username ${var.redis_user} password '${var.redis_password}' nodes ${aws_network_interface.cluster_nic[0].private_ip} flash_enabled replace_node ${count.index + 1}"

  if $rack_aware ; then
    command="$command rack_id '${sort(var.availability_zones)[count.index % length(var.availability_zones)]}'"
  fi

  if ! $private_conf; then
    command="$command external_addr $node_external_addr"
  fi

  echo "Command: $command" >> /home/${var.ssh_user}/install_redis.log

  # Retry loop for joining cluster (master node might not be ready yet)
  max_retries=20
  retry_count=0
  while [ $retry_count -lt $max_retries ]; do
    echo "$(date) - Join attempt $((retry_count + 1))/$max_retries" >> /home/${var.ssh_user}/install_redis.log
    if sudo bash -c "$command" >> /home/${var.ssh_user}/install_redis.log 2>&1; then
      echo "$(date) - Successfully joined cluster" >> /home/${var.ssh_user}/install_redis.log
      break
    else
      echo "$(date) - Join failed, retrying in 30 seconds..." >> /home/${var.ssh_user}/install_redis.log
      retry_count=$((retry_count + 1))
      sleep 30
    fi
  done

  if [ $retry_count -eq $max_retries ]; then
    echo "$(date) - ERROR: Failed to join cluster after $max_retries attempts" >> /home/${var.ssh_user}/install_redis.log
  fi
fi
echo "$(date) - DONE creating cluster node" >> /home/${var.ssh_user}/install_redis.log

################
# NODE external_addr - script for updating external_addr on reboot (for dynamic IPs)
echo "${count.index + 1}" > /home/${var.ssh_user}/node_index.terraform
if ! $private_conf; then
  # Create script that reads node index from file and updates external_addr
  cat > /home/${var.ssh_user}/node_externaladdr.sh << 'EXTERNALADDRSCRIPT'
#!/bin/bash
# This script updates the Redis Enterprise node's external address
# Useful when cloud instances have dynamic public IPs

node_external_addr=$(curl -s ifconfig.me/ip)
node_index=$(cat /home/ubuntu/node_index.terraform 2>/dev/null || echo "1")

echo "Updating node $node_index external_addr to $node_external_addr"
/opt/redislabs/bin/rladmin node "$node_index" external_addr set "$node_external_addr" 2>&1 || true
EXTERNALADDRSCRIPT
  chown ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/node_externaladdr.sh
  chmod u+x /home/${var.ssh_user}/node_externaladdr.sh
  # Don't run it now - external_addr was already set during cluster create/join
  echo "$(date) - Created node_externaladdr.sh script for future use" >> /home/${var.ssh_user}/install_redis.log
fi

echo "$(date) - user_data script completed"
USERDATA

  tags = merge("${var.resource_tags}",{
    Name = "${var.name}-node-${count.index}"
  })
}

#resource "aws_volume_attachment" "datadisk" {
#  device_name = "/dev/sdc"
#  volume_id   = aws_ebs_volume.datadisk[count.index].id
#  instance_id = aws_instance.node[count.index].id
#  count       = var.worker_count
#}
#resource "aws_ebs_volume" "datadisk" {
#  availability_zone = sort(var.availability_zones)[count.index % length(var.availability_zones)]
#  size              = 5000
#  type              = "gp2"
#  count             = var.worker_count
#
#  tags = merge("${var.resource_tags}",{
#    Name = "${var.name}-datadisk-${count.index}"
#  })
#}

