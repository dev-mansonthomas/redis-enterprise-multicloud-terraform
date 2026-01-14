# =============================================================================
# Dynamic Availability Zone Discovery
# =============================================================================
# This file fetches available zones dynamically for each region,
# eliminating the need for hardcoded zone names in variables.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Fetch available AZs in Region 1
data "aws_availability_zones" "region_1" {
  provider = aws.provider1
  state    = "available"
}

# Fetch available AZs in Region 2
data "aws_availability_zones" "region_2" {
  provider = aws.provider2
  state    = "available"
}

# =============================================================================
# Local variables to construct dynamic subnets
# =============================================================================
locals {
  # Get the first available AZ in each region
  az_region_1 = data.aws_availability_zones.region_1.names[0]
  az_region_2 = data.aws_availability_zones.region_2.names[0]

  # Dynamically construct subnet maps using the actual AZ names
  # For Basic_Clusters (non rack-aware), we only need 1 AZ per region
  # Use var values if provided, otherwise use dynamic values
  effective_subnets_1 = length(var.subnets_1) > 0 ? var.subnets_1 : {
    (local.az_region_1) = "10.1.1.0/24"
  }

  effective_subnets_2 = length(var.subnets_2) > 0 ? var.subnets_2 : {
    (local.az_region_2) = "10.2.1.0/24"
  }

  effective_bastion_1_subnet = length(var.bastion_1_subnet) > 0 ? var.bastion_1_subnet : {
    (local.az_region_1) = "10.1.4.0/24"
  }

  effective_bastion_2_subnet = length(var.bastion_2_subnet) > 0 ? var.bastion_2_subnet : {
    (local.az_region_2) = "10.2.4.0/24"
  }
}

