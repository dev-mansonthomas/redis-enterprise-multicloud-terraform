variable "name" {
  description = "Deployment name, also used as prefix for resources: <name>-<VPC>"
  type        = string
}

variable "subnets" {
  description = "List of private subnets"
  type        = list
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
}

variable "security_groups" {
  description = "list of security group IDs for the private subnet"
  type        = list
}

variable "machine_image" {
  description = "Virtual machine image (OS)"
  type        = string
}

variable "region" {
  description = "Region for the VCP/VNET deployment"
  type        = string
}

variable "machine_type" {
  description = "Hardwaretype for Redis cluster nodes"
  type        = string
}

variable "resource_group" {
  description = "Azure resourcegroup for the deployment"
  type        = string
}

variable "ssh_public_key" {
  description = "Path to SSH public key"
  type        = string
}

variable "ssh_private_key" {
  description = "Path to SSH private key (for provisioners)"
  type        = string
}

variable "ssh_user" {
  description = "SSH linux user"
  type        = string
}

variable "worker_count" {
  description = "number of Redis cluster nodes to be deployed"
  type        = string
}

variable "resource_tags" {
  description = "hash with tags for all resources"
}

variable "redis_distro" {
  description = "Redis distribution"
  type        = string
}

variable "redis_user" {
  description = "Redis Cluster Admin User"
  type        = string
}

variable "redis_password" {
  description = "Redis Cluster Admin Password"
  type        = string
  # sensitive = true  # Commented for demo/POC transparency
}

variable "cluster_dns" {
  description = "Redis Cluster DNS"
  type        = string
}

variable "rack_aware" {
  description = "Rack AZ Awareness"
  type        = bool
}

variable "boot_disk_size" {
  description = "Volume Size"
  type        = number
}

variable "boot_disk_type" {
  description = "Volume Type"
  type        = string
}

variable "private_conf" {
  description = "Flag of private configuration"
  type        = bool
}

variable "flash_enabled" {
  description = "Enable Redis on Flash"
  type        = bool
  default     = false
}

variable "data_disk_count" {
  description = "Number of data disks for RAID 0. For Lsv3 instances, use 0 (they have NVMe built-in)."
  type        = number
  default     = 0
}

variable "data_disk_size" {
  description = "Size in GB for each data disk (total RAID size = count * size)"
  type        = number
  default     = 512
}

variable "data_disk_type" {
  description = "Managed disk type: Premium_LRS, PremiumV2_LRS (best perf), UltraSSD_LRS"
  type        = string
  default     = "PremiumV2_LRS"
}

variable "data_disk_iops" {
  description = "Provisioned IOPS for PremiumV2 or Ultra disks"
  type        = number
  default     = 80000
}

variable "data_disk_throughput" {
  description = "Throughput in MB/s for PremiumV2 or Ultra disks"
  type        = number
  default     = 1200
}