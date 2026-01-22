variable "deployment_name" {
  description = "Deployment Name"
  # No default
  # Use CLI or interactive input.
}

variable "region_1_name" {
  default = "us-east-1"
}

variable "vpc_1_cidr" {
  default = "10.1.0.0/16"
}

variable "subnets_1" {
  description = "Subnet map for region 1 {az_name = cidr}. Leave empty for dynamic AZ discovery (3 AZs)."
  type    = map(string)
  default = {}
}

variable "client_1_enabled" {
  // When a private configuration is enabled, this flag should be enabled !
  default = true
}

variable "bastion_1_subnet" {
  description = "Bastion subnet map for region 1 {az_name = cidr}. Leave empty for dynamic AZ discovery."
  type    = map(string)
  default = {}
}

variable "region_2_name" {
  default = "us-west-2"
}

variable "vpc_2_cidr" {
  default = "10.2.0.0/16"
}

variable "subnets_2" {
  description = "Subnet map for region 2 {az_name = cidr}. Leave empty for dynamic AZ discovery (3 AZs)."
  type    = map(string)
  default = {}
}

variable "client_2_enabled" {
  // When a private configuration is enabled, this flag should be enabled !
  default = true
}

variable "bastion_2_subnet" {
  description = "Bastion subnet map for region 2 {az_name = cidr}. Leave empty for dynamic AZ discovery."
  type    = map(string)
  default = {}
}

variable "rack_aware" {
  default = true
}

variable "private_conf" {
  default = false
}

variable "aws_access_key" {
  description = "AWS Access Key"
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
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
  default = 200
}

variable "volume_type" {
  default = "gp3"
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

variable "machine_type" {
  default = "t2.2xlarge"
}

variable "bastion_machine_type" {
  description = "Instance type for bastion/client (memtier, Prometheus, Grafana)"
  default = "c5.xlarge"
}

variable "machine_image_region_1" {
  // Ubuntu 20.04 LTS
  default = "ami-0261755bbcb8c4a84"
}

variable "machine_image_region_2" {
  // Ubuntu 20.04 LTS
  default = "ami-0c65adc9a5c1b5d7c"
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
// cluster.<envX>-<project_name>.demo-rlec.redislabs.com
// node1.cluster.<envX>-<project_name>.demo-rlec.redislabs.com
// node2.cluster.<envX>-<project_name>.demo-rlec.redislabs.com
// node3.cluster.<envX>-<project_name>.demo-rlec.redislabs.com
variable "hosted_zone" {
  default = "demo-rlec.redislabs.com"
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