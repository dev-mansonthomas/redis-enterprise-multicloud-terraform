# ============================================================================
# DYNAMIC AVAILABILITY ZONES AND SUBNETS FOR CROSS-REGION
# Automatically discovers available zones in both regions and generates
# subnet CIDR blocks dynamically. No more hardcoded zone names!
# ============================================================================

# Fetch all available zones in Region 1
data "google_compute_zones" "region_1" {
  provider = google.provider1
  project  = var.project_1
  region   = var.region_1_name
  status   = "UP"
}

# Fetch all available zones in Region 2
data "google_compute_zones" "region_2" {
  provider = google.provider2
  project  = var.project_2
  region   = var.region_2_name
  status   = "UP"
}

locals {
  # ============================================================================
  # REGION 1 - ZONE SELECTION
  # For Rack-Aware Cluster: use up to 3 zones for proper distribution
  # ============================================================================
  
  # Get all available zones sorted alphabetically
  all_zones_1 = sort(data.google_compute_zones.region_1.names)
  
  # For Rack-Aware, we need 3 zones (or all available if less than 3)
  num_zones_1_needed = min(3, length(local.all_zones_1))
  selected_zones_1   = slice(local.all_zones_1, 0, local.num_zones_1_needed)
  
  # Bastion goes in the second zone (or first if only one available)
  bastion_zone_1 = length(local.all_zones_1) > 1 ? local.all_zones_1[1] : local.all_zones_1[0]
  
  # ============================================================================
  # REGION 2 - ZONE SELECTION
  # ============================================================================
  
  all_zones_2 = sort(data.google_compute_zones.region_2.names)
  
  num_zones_2_needed = min(3, length(local.all_zones_2))
  selected_zones_2   = slice(local.all_zones_2, 0, local.num_zones_2_needed)
  
  bastion_zone_2 = length(local.all_zones_2) > 1 ? local.all_zones_2[1] : local.all_zones_2[0]
  
  # ============================================================================
  # DYNAMIC SUBNET GENERATION
  # Region 1: Base CIDR 10.1.0.0/16 -> 10.1.1.0/24, 10.1.2.0/24, 10.1.3.0/24
  # Region 2: Base CIDR 10.2.0.0/16 -> 10.2.1.0/24, 10.2.2.0/24, 10.2.3.0/24
  # ============================================================================
  
  # Region 1 subnets
  computed_subnets_1 = {
    for idx, zone in local.selected_zones_1 :
    zone => "10.1.${idx + 1}.0/24"
  }
  
  # Region 1 bastion subnet
  computed_bastion_1_subnet = {
    (local.bastion_zone_1) = "10.1.4.0/24"
  }
  
  # Region 2 subnets
  computed_subnets_2 = {
    for idx, zone in local.selected_zones_2 :
    zone => "10.2.${idx + 1}.0/24"
  }
  
  # Region 2 bastion subnet
  computed_bastion_2_subnet = {
    (local.bastion_zone_2) = "10.2.4.0/24"
  }
}

