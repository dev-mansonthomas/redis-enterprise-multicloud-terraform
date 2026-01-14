# =============================================================================
# Dynamic Availability Zone Discovery for Rack-Aware Clusters
# =============================================================================
# This file fetches available zones dynamically for each region,
# eliminating the need for hardcoded zone names in variables.
# Rack-aware clusters need 3 AZs per region for high availability.

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
  # Get the first 3 available AZs in each region (for rack-aware)
  azs_region_1 = slice(data.aws_availability_zones.region_1.names, 0, min(3, length(data.aws_availability_zones.region_1.names)))
  azs_region_2 = slice(data.aws_availability_zones.region_2.names, 0, min(3, length(data.aws_availability_zones.region_2.names)))

  # Dynamically construct subnet maps using the actual AZ names
  # For Rack_Aware_Clusters, we need 3 AZs per region
  # Use var values if provided (non-empty), otherwise use dynamic values
  effective_subnets_1 = length(var.subnets_1) > 0 ? var.subnets_1 : {
    for idx, az in local.azs_region_1 : az => "10.1.${idx + 1}.0/24"
  }

  effective_subnets_2 = length(var.subnets_2) > 0 ? var.subnets_2 : {
    for idx, az in local.azs_region_2 : az => "10.2.${idx + 1}.0/24"
  }

  # Bastion uses only the first AZ
  effective_bastion_1_subnet = length(var.bastion_1_subnet) > 0 ? var.bastion_1_subnet : {
    (local.azs_region_1[0]) = "10.1.4.0/24"
  }

  effective_bastion_2_subnet = length(var.bastion_2_subnet) > 0 ? var.bastion_2_subnet : {
    (local.azs_region_2[0]) = "10.2.4.0/24"
  }
}

