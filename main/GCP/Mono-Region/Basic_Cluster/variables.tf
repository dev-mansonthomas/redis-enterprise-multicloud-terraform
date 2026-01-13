variable "deployment_name" {
  description = "Deployment Name"
  # No default
  # Use CLI or interactive input.
}

variable "project" {
  default = "central-beach-194106"
}

variable "region_name" {
  default = "europe-west1"
}

variable "rack_aware" {
  default = false
}

variable "subnets" {
  type = map
  default = {
    europe-west1-b = "10.1.1.0/24"
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
    europe-west1-c = "10.1.4.0/24"
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

variable "credentials" {
  description = "GCP credentials file"
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
  description = "Boot disk size in GB"
  default     = 50
}

variable "volume_type" {
  description = "Boot disk type: pd-ssd (default), pd-balanced, pd-extreme"
  default     = "pd-ssd"
}

// ============================================================================
// LOCAL SSD FOR REDIS ON FLASH (RAID 0)
// GCP Local SSDs are 375GB each, attached directly to the host
// Total flash storage = local_ssd_count * 375 GB
// ============================================================================
variable "local_ssd_count" {
  description = "Number of local SSDs (375GB each) for RAID 0"
  type        = number
  default     = 2  # 750 GB total
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

// ============================================================================
// INSTANCE TYPE CONFIGURATION
// ============================================================================
// PERFORMANCE (Redis on Flash POC) - supports Local SSDs:
//   - n2-standard-8   : 8 vCPU, 32 GB RAM (~$0.39/hr)
//   - n2-standard-16  : 16 vCPU, 64 GB RAM (~$0.78/hr)
//   - n2-highmem-8    : 8 vCPU, 64 GB RAM (~$0.52/hr) - more memory
//   - c2-standard-8   : 8 vCPU, 32 GB RAM (~$0.42/hr) - compute optimized
//
// GENERAL PURPOSE (Demo/Dev) - NO Local SSD support:
//   - e2-standard-4   : 4 vCPU, 16 GB RAM (~$0.13/hr)
//   - e2-standard-8   : 8 vCPU, 32 GB RAM (~$0.27/hr)
//
// NOTE: E2 instances do NOT support Local SSDs!
// ============================================================================
variable "machine_type" {
  # Performance config: n2-standard-8 (supports Local SSDs for Flash)
  default = "n2-standard-8"
  # Demo config: "e2-standard-4" (no Local SSD support)
}

variable "bastion_machine_type" {
  description = "Instance type for bastion/client (memtier, Prometheus, Grafana)"
  # Budget: e2-standard-4 (4 vCPU, 16GB, 10 Gbps)
  # Performance: c2-standard-4 (4 vCPU, 16GB, 32 Gbps)
  default = "e2-standard-4"
}

variable "machine_image" {
  // Ubuntu 20.04 LTS
  default = "ubuntu-minimal-2004-lts"
}

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
// cluster.<env>-<project_name>.demo.redislabs.com
// node1.cluster.<env>-<project_name>.demo.redislabs.com
// node2.cluster.<env>-<project_name>.demo.redislabs.com
// node3.cluster.<env>-<project_name>.demo.redislabs.com
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