#!/bin/bash
# =============================================================================
# Interactive deployment menu for Redis Enterprise Terraform configurations
# Usage: ./deploy.sh
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "$PROJECT_ROOT/scripts/common.sh"

# Script mapping
declare -a SCRIPTS=(
    ""  # 0 = exit
    "./aws_mono_region_basic.sh"
    "./aws_mono_region_rack_aware.sh"
    "./aws_cross_region_basic.sh"
    "./aws_cross_region_rack_aware.sh"
    "./gcp_mono_region_basic.sh"
    "./gcp_mono_region_rack_aware.sh"
    "./gcp_cross_region_basic.sh"
    "./gcp_cross_region_rack_aware.sh"
    "./gcp_gke_mono_region_basic.sh"
    "./gcp_gke_mono_region_rack_aware.sh"
    "./gcp_gke_cross_region_basic.sh"
    "./gcp_gke_cross_region_rack_aware.sh"
    "./azure_mono_region_basic.sh"
    "./azure_mono_region_rack_aware.sh"
    "./azure_cross_region_basic.sh"
    "./azure_cross_region_rack_aware.sh"
    "./azure_acre_enterprise.sh"
    "./azure_acre_oss.sh"
)

clear
log_header "Redis Enterprise Deployment Menu"
echo ""
echo "Select a configuration:"
echo ""
echo "AWS Configurations:"
echo "  1) AWS Mono-Region Basic Cluster"
echo "  2) AWS Mono-Region Rack-Aware Cluster"
echo "  3) AWS Cross-Region Basic Clusters"
echo "  4) AWS Cross-Region Rack-Aware Clusters"
echo ""
echo "GCP Configurations:"
echo "  5) GCP Mono-Region Basic Cluster"
echo "  6) GCP Mono-Region Rack-Aware Cluster"
echo "  7) GCP Cross-Region Basic Clusters"
echo "  8) GCP Cross-Region Rack-Aware Clusters"
echo ""
echo "GCP GKE Configurations:"
echo "  9) GCP GKE Mono-Region Basic Cluster"
echo " 10) GCP GKE Mono-Region Rack-Aware Cluster"
echo " 11) GCP GKE Cross-Region Basic Clusters"
echo " 12) GCP GKE Cross-Region Rack-Aware Clusters"
echo ""
echo "Azure Configurations:"
echo " 13) Azure Mono-Region Basic Cluster"
echo " 14) Azure Mono-Region Rack-Aware Cluster"
echo " 15) Azure Cross-Region Basic Clusters"
echo " 16) Azure Cross-Region Rack-Aware Clusters"
echo ""
echo "Azure ACRE Configurations:"
echo " 17) Azure ACRE Enterprise"
echo " 18) Azure ACRE OSS"
echo ""
echo "  0) Exit"
echo ""
read -p "Enter your choice [0-18]: " choice

# Validate choice
if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -gt 18 ]; then
    log_error "Invalid choice. Please select a number between 0 and 18."
    exit 1
fi

# Handle exit
if [ "$choice" -eq 0 ]; then
    echo "Exiting..."
    exit 0
fi

# Ask for action
echo ""
echo "Select action:"
echo "  1) Deploy (create/update infrastructure)"
echo "  2) Destroy (remove infrastructure)"
echo ""
read -p "Enter action [1-2]: " action

case $action in
    1)
        ACTION_FLAG=""
        ;;
    2)
        ACTION_FLAG="--destroy"
        echo ""
        log_warn "You are about to DESTROY the infrastructure."
        read -p "Are you sure? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "Aborted."
            exit 0
        fi
        ;;
    *)
        log_error "Invalid action. Please select 1 or 2."
        exit 1
        ;;
esac

# Execute the selected script
${SCRIPTS[$choice]} $ACTION_FLAG
