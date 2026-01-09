#!/bin/bash
# =============================================================================
# GCP GKE Cross-Region Basic Clusters deployment
# Usage: ./gcp_gke_cross_region_basic.sh [--destroy]
# =============================================================================

CONFIG_DIR="main/GCP/GKE/Cross-Region/Basic_Clusters"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="apply"

# Parse arguments
if [[ "$1" == "--destroy" ]]; then
    ACTION="destroy"
fi

# Source common functions and GCP provider
source "$PROJECT_ROOT/scripts/common.sh"
source "$PROJECT_ROOT/scripts/providers/gcp.sh"

if [[ "$ACTION" == "destroy" ]]; then
    log_header "GCP GKE Cross-Region Basic Clusters - DESTROY"
else
    log_header "GCP GKE Cross-Region Basic Clusters"
fi
echo "Configuration: $CONFIG_DIR"

# Check if directory exists
if [ ! -d "$CONFIG_DIR" ]; then
    log_error "Configuration directory not found: $CONFIG_DIR"
    exit 1
fi

# Load environment and run pre-flight checks BEFORE cd
load_env "$PROJECT_ROOT" || exit 1
preflight_gcp || exit 1

# Navigate to the configuration directory
cd "$CONFIG_DIR" || exit 1

# Run the appropriate script
if [[ "$ACTION" == "destroy" ]]; then
    if [ -f "tofu_destroy.sh" ]; then
        ./tofu_destroy.sh
    else
        log_error "tofu_destroy.sh not found in $CONFIG_DIR"
        exit 1
    fi
else
    if [ -f "tofu_apply.sh" ]; then
        ./tofu_apply.sh
    else
        log_error "tofu_apply.sh not found in $CONFIG_DIR"
        exit 1
    fi
fi
