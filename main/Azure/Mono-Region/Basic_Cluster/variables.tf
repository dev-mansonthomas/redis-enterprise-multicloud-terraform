variable "deployment_name" {
  description = "Deployment Name"
  # No default
  # Use CLI or interactive input.
}

variable "region_name" {
  default = "East US"
}

variable "vnet_cidr" {
  default = "10.1.0.0/16"
}

variable "rack_aware" {
  default = false
}

variable "subnets" {
  type = map
  default = {
    1 = "10.1.1.0/24"
  }
}

variable "private_conf" {
  default = false
}

variable "client_enabled" {
  default = true
}

variable "bastion_subnet" {
  type = map
  default = {
    1 = "10.1.4.0/24"
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

variable "azure_access_key_id" {
  description = "Azure Client ID (Application ID). Leave empty to use Azure CLI authentication."
  default     = ""
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID. Leave empty to use Azure CLI authentication."
  default     = ""
}

variable "azure_subscription_id" {
  description = "Azure Subscription ID. Required for all authentication methods."
}

variable "azure_secret_key" {
  description = "Azure Client Secret. Leave empty to use Azure CLI authentication."
  default     = ""
}

variable "use_cli_auth" {
  description = "Use Azure CLI authentication instead of Service Principal"
  type        = bool
  default     = false
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
  # Boot disk type: Premium_LRS recommended for OS
  default = "Premium_LRS"
}

// ============================================================================
// DATA DISKS FOR REDIS ON FLASH (RAID 0)
// For Lsv3 instances with built-in NVMe, set data_disk_count = 0
// Total flash storage = data_disk_count * data_disk_size
// ============================================================================
variable "data_disk_count" {
  description = "Number of data disks for RAID 0 (0 = use built-in NVMe for Lsv3)"
  type        = number
  default     = 0  # Lsv3 has built-in NVMe
}

variable "data_disk_size" {
  description = "Size in GB per data disk"
  type        = number
  default     = 512
}

variable "data_disk_type" {
  description = "Disk type: PremiumV2_LRS (best perf), Premium_LRS, UltraSSD_LRS"
  type        = string
  default     = "PremiumV2_LRS"
}

variable "data_disk_iops" {
  description = "Provisioned IOPS for PremiumV2/Ultra"
  type        = number
  default     = 80000
}

variable "data_disk_throughput" {
  description = "Throughput MB/s for PremiumV2/Ultra"
  type        = number
  default     = 1200
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
// PERFORMANCE (Redis on Flash POC) - Storage Optimized with NVMe:
//   - Standard_L8s_v3  : 8 vCPU, 64 GB RAM, 1x1.92 TB NVMe (~$0.62/hr)
//   - Standard_L16s_v3 : 16 vCPU, 128 GB RAM, 2x1.92 TB NVMe (~$1.25/hr)
//   - Standard_L32s_v3 : 32 vCPU, 256 GB RAM, 4x1.92 TB NVMe (~$2.49/hr)
//
// GENERAL PURPOSE (Demo/Dev):
//   - Standard_D4s_v3  : 4 vCPU, 16 GB RAM (~$0.19/hr)
//   - Standard_D8s_v3  : 8 vCPU, 32 GB RAM (~$0.38/hr)
//   - Standard_E8s_v3  : 8 vCPU, 64 GB RAM (~$0.50/hr) - memory optimized
// ============================================================================
variable "machine_type" {
  # Performance config: Standard_L8s_v3 (storage optimized with NVMe)
  default = "Standard_L8s_v3"
  # Demo config: "Standard_D4s_v3" or "Standard_D8s_v3"
}

variable "bastion_machine_type" {
  description = "Instance type for bastion/client (memtier, Prometheus, Grafana)"
  default = "Standard_D4s_v5"
}

variable "machine_image" {
  // Ubuntu 20.04 LTS
  default = "Canonical:0001-com-ubuntu-minimal-focal:minimal-20_04-lts-gen2:latest"
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
// cluster.<env>-<project_name>.demo-azure.redislabs.com
// node1.cluster.<env>-<project_name>.demo-azure.redislabs.com
// node2.cluster.<env>-<project_name>.demo-azure.redislabs.com
// node3.cluster.<env>-<project_name>.demo-azure.redislabs.com
variable "hosted_zone" {
  default = "demo-azure.redislabs.com"
}

variable "dns_resource_group" {
  description = "Azure resource group containing the DNS zone (can be different from deployment resource group)"
  type        = string
  default     = ""
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