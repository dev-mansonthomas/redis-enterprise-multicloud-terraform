variable "deployment_name" {
  description = "Deployment Name"
  # No default
  # Use CLI or interactive input.
}

variable "project_1" {
  default = "central-beach-194106"
}

variable "region_1_name" {
  default = "europe-west1"
}

variable "project_2" {
  default = "central-beach-194106"
}

variable "region_2_name" {
  default = "us-east1"
}

variable "env1" {
  default = "europe"
}

variable "env2" {
  default = "us"
}

variable "private_conf" {
  default = false
}

variable "client_1_enabled" {
  // When a private configuration is enabled, this flag should be enabled !
  default = true
}

variable "subnets_1" {
  type = map
  default = {
    europe-west1-b = "10.1.1.0/24"
  }
}

variable "bastion_1_subnet" {
  type = map
  default = {
    europe-west1-c = "10.1.4.0/24"
  }
}

variable "client_2_enabled" {
  // When a private configuration is enabled, this flag should be enabled !
  default = true
}

variable "subnets_2" {
  type = map
  default = {
    us-east1-b = "10.2.1.0/24"
  }
}

variable "bastion_2_subnet" {
  type = map
  default = {
    us-east1-c = "10.2.4.0/24"
  }
}

variable "rack_aware" {
  default = false
}

variable "credentials_1" {
  description = "GCP credentials file for Project/Region 1"
  default = "terraform_account.json"
  # sensitive = true  # Commented for demo/POC transparency
}

variable "credentials_2" {
  description = "GCP credentials file for Project/Region 2"
  default = "terraform_account.json"
  # sensitive = true  # Commented for demo/POC transparency
}

variable "ssh_public_key" {
  default = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key" {
  description = "Path to SSH private key for provisioners"
  default     = "~/.ssh/id_rsa"
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
  default = 40
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

variable "machine_type" {
  default = "e2-standard-2"
  // For Redis on Flash:
  // You can create a VM instance with a maximum of 16 or 24 local SSD partitions for 6 TB or 9 TB of local SSD space, respectively, using N1, N2, and N2D machine types. Try this : "n2-highcpu-16"  // 16 vCPU 32 GB
  // For C2, C2D, A2, M1, and M3 machine types, you can create a VM with a maximum of 8 local SSD partitions, for a total of 3 TB local SSD space.
  // You can't attach Local SSDs to E2, Tau T2D, Tau T2A, and M2 machine types.
}

variable "bastion_machine_type" {
  description = "Instance type for bastion/client (memtier, Prometheus, Grafana)"
  default = "e2-standard-4"
}

variable "machine_image" {
  // Ubuntu 20.04 LTS
  default = "ubuntu-minimal-2004-lts"
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
// cluster.<envX>-<project_name>.demo.redislabs.com
// node1.cluster.<envX>-<project_name>.demo.redislabs.com
// node2.cluster.<envX>-<project_name>.demo.redislabs.com
// node3.cluster.<envX>-<project_name>.demo.redislabs.com
variable "hosted_zone" {
  default = "demo.redislabs.com"
}

variable "hosted_zone_name" {
  default = "demo-clusters"
}

# ============================================
# TAGGING CONFIGURATION
# ============================================
variable "owner" {
  description = "Owner label for all resources (format: firstname_lastname)"
  type        = string
}

variable "skip_deletion" {
  description = "Skip deletion label for resources that should not be deleted"
  type        = string
  default     = "yes"
}