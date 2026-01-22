variable "name" {
  description = "Deployment name, also used as prefix for resources: <name>-<VPC>"
  type        = string
}

variable "region" {
  description = "Region for the Resource Group Creation"
  type        = string
}

variable "resource_tags" {
  description = "Tags to apply to the resource group"
  type        = map(string)
  default     = {}
}