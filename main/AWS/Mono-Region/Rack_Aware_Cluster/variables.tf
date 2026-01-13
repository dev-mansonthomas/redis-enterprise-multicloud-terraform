variable "deployment_name" {
  description = "Deployment Name"
  # No default
  # Use CLI or interactive input.
}

variable "region_name" {
  default = "eu-west-3"
}

variable "vpc_cidr" {
  default = "10.1.0.0/16"
}

variable "rack_aware" {
  default = true
}

variable "subnets" {
  type = map
  default = {
    eu-west-3a = "10.1.1.0/24"
    eu-west-3b = "10.1.2.0/24"
    eu-west-3c = "10.1.3.0/24"
  }
}

variable "private_conf" {
  default = false
}

variable "client_enabled" {
  // When a private configuration is enabled, this flag should be enabled !
  default = true
}

variable "bastion_subnet" {
  type = map
  default = {
    eu-west-3a = "10.1.4.0/24"
  }
}

# Packages to install in the client machine
variable "memtier_package" {
  description = "Memtier package URI"
  default = "https://github.com/RedisLabs/memtier_benchmark/archive/refs/tags/1.4.0.tar.gz"
}

variable "redis_stack_package" {
  description = "Redis Stack package URI"
  default = "https://redismodules.s3.amazonaws.com/redis-stack/redis-stack-server-6.2.6-v7.bionic.x86_64.tar.gz"
}

variable "promethus_package" {
  description = "Prometheus package URI"
  default = "https://github.com/prometheus/prometheus/releases/download/v2.37.0/prometheus-2.37.0.linux-amd64.tar.gz"
}

variable "redis_insight_package" {
  description = "Redis Insight package URI"
  default = "https://downloads.redisinsight.redislabs.com/1.1.0/redisinsight-linux64"
}

variable "aws_access_key" {
  description = "AWS Access Key"
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
}

variable "ssh_public_key" {
  default = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key" {
  description = "Path to SSH private key for provisioners"
  default     = "~/.ssh/id_ed25519"
}

variable "ssh_user" {
  default = "ubuntu"
}

variable "flash_enabled" {
  description = "Enable Redis on Flash"
  type        = bool
  default     = false
}

variable "volume_size" {
  default = 200
}

variable "volume_type" {
  default = "gp2"
}

// other optional edits *************************************
variable "cluster_size" {
  # You should use 3 for some more realistic installation
  default = 3
}

// other possible edits *************************************
variable "rs_release" {
  description = "Redis Enterprise download URL (set via REDIS_ENTERPRISE_URL in .env)"
  type        = string
}

variable "machine_type" {
  default = "t2.2xlarge"
}

variable "bastion_machine_type" {
  description = "Instance type for bastion/client (memtier, Prometheus, Grafana)"
  # Budget: c5.xlarge (4 vCPU, 8GB, 10 Gbps)
  # Performance: c5n.xlarge (4 vCPU, 10.5GB, 25 Gbps)
  default = "c5.xlarge"
}

variable "machine_image" {
  // Ubuntu 22.04 LTS
  default = "ami-007c433663055a1cc"
}// Ubuntu 20.04 LTS ami-0261755bbcb8c4a84

variable "env" {
  default = "dev"
}

variable "rs_user" {
  description = "Redis Enterprise admin email (required - set REDIS_LOGIN in .env)"
  type        = string
}

variable "rs_password" {
  description = "Redis Enterprise admin password (required - set REDIS_PWD in .env)"
  type        = string
}

// RS DNS and cluster will be
// cluster.<env>-<project_name>.demo-rlec.redislabs.com
// node1.cluster.<env>-<project_name>.demo-rlec.redislabs.com
// node2.cluster.<env>-<project_name>.demo-rlec.redislabs.com
// node3.cluster.<env>-<project_name>.demo-rlec.redislabs.com
variable "hosted_zone" {
  default = "aws.paquerette.com"
}

# ============================================
# TAGGING CONFIGURATION
# ============================================
variable "owner" {
  description = "Owner tag for all resources (format: firstname_lastname)"
  type        = string
}

variable "skip_deletion" {
  description = "Skip deletion tag for resources that should not be deleted"
  type        = string
  default     = "yes"
}