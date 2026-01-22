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
  default = true
}

# NOTE: subnets and bastion_subnet are now dynamically generated in data.tf
# based on the available zones in the selected region.
# See local.computed_subnets and local.computed_bastion_subnet

variable "private_conf" {
  default = false
}

variable "client_enabled" {
    // When a private configuration is enabled, this flag should be enabled !
  default = true
}

# Bastion tools - versions configured in .env, URLs built by scripts/common.sh
variable "memtier_package" {
  description = "Memtier benchmark package URL"
  type        = string
}

variable "prometheus_package" {
  description = "Prometheus package URL"
  type        = string
}

variable "grafana_version" {
  description = "Grafana version to install"
  type        = string
}

variable "java_version" {
  description = "Java version to install"
  type        = string
  default     = "21"
}

variable "redis_cli_version" {
  description = "Redis CLI version to install"
  type        = string
  default     = "8.4.0"
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