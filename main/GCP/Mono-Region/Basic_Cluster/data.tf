# ============================================================================
# DYNAMIC AVAILABILITY ZONES AND SUBNETS
# Automatically discovers available zones in the selected region and generates
# subnet CIDR blocks dynamically. No more hardcoded zone names!
# ============================================================================

# Fetch all available zones in the region
data "google_compute_zones" "available" {
  project = var.project
  region  = var.region_name
  status  = "UP"
}

locals {
  # ============================================================================
  # ZONE SELECTION
  # For Basic Cluster (non rack-aware): use only the first zone
  # ============================================================================
  
  # Get all available zones sorted alphabetically
  all_zones = sort(data.google_compute_zones.available.names)
  
  # For Basic Cluster, we only need 1 zone (first available)
  selected_zones = [local.all_zones[0]]
  
  # Bastion goes in the first zone as well
  bastion_zone = local.all_zones[0]
  
  # ============================================================================
  # DYNAMIC SUBNET GENERATION
  # Base CIDR: 10.1.0.0/16
  # Subnets:   10.1.1.0/24, 10.1.2.0/24, 10.1.3.0/24, etc.
  # Bastion:   10.1.4.0/24
  # ============================================================================
  
  # Generate subnet CIDRs for each selected zone
  # zone -> CIDR mapping: first zone gets 10.1.1.0/24, second gets 10.1.2.0/24, etc.
  computed_subnets = {
    for idx, zone in local.selected_zones :
    zone => "10.1.${idx + 1}.0/24"
  }
  
  # Bastion subnet (always 10.1.4.0/24 to leave room for cluster subnets)
  computed_bastion_subnet = {
    (local.bastion_zone) = "10.1.4.0/24"
  }
}

