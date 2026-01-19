variable "deployment_name" {
  description = "Deployment Name"
  # No default
  # Use CLI or interactive input.
}

variable "region_1_name" {
  default = "East US"
}

variable "vnet_1_cidr" {
  default = "10.1.0.0/16"
}

variable "rack_aware" {
  default = true
}

variable "subnets_1" {
  type = map
  default = {
    1 = "10.1.1.0/24"
    2 = "10.1.2.0/24"
    3 = "10.1.3.0/24"
  }
}

variable "bastion_1_subnet" {
  type = map
  default = {
    1 = "10.1.4.0/24"
  }
}

variable "private_conf" {
  default = false
}

variable "client_enabled" {
  default = true
}

variable "region_2_name" {
  default = "West US 2"
}

variable "vnet_2_cidr" {
  default = "10.2.0.0/16"
}

variable "subnets_2" {
  type = map
  default = {
    1 = "10.2.1.0/24"
    2 = "10.2.2.0/24"
    3 = "10.2.3.0/24"
  }
}

variable "bastion_2_subnet" {
  type = map
  default = {
    1 = "10.2.4.0/24"
  }
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
  default = 40
}

variable "volume_type" {
  default = "Premium_LRS"
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
  default = "Standard_D2s_v3"
}

variable "bastion_machine_type" {
  description = "Instance type for bastion/client (memtier, Prometheus, Grafana)"
  default = "Standard_D4s_v5"
}

variable "machine_image" {
  // Ubuntu 20.04 LTS
  default = "Canonical:0001-com-ubuntu-minimal-focal:minimal-20_04-lts-gen2:latest"
}

variable "env1" {
  default = "east"
}

variable "env2" {
  default = "west"
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
// cluster.<envX>-<project_name>.demo-azure.redislabs.com
// node1.cluster.<envX>-<project_name>.demo-azure.redislabs.com
// node2.cluster.<envX>-<project_name>.demo-azure.redislabs.com
// node3.cluster.<envX>-<project_name>.demo-azure.redislabs.com
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