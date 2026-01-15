#!/bin/bash
# =============================================================================
# GCP Quota Check Utility
# Lists available CPU quotas by region to help choose the right region/machine
# Usage: ./scripts/gcp_quota_check.sh [region]
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load .env if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# Get project ID
PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: No GCP project configured${NC}"
    echo "Set GCP_PROJECT_ID in .env or run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}GCP CPU Quota Check - Project: $PROJECT_ID${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Function to get quota for a specific region
get_region_quota() {
    local region=$1
    echo -e "${YELLOW}Region: $region${NC}"
    
    # Get CPU quotas
    gcloud compute regions describe "$region" --project="$PROJECT_ID" \
        --format="table[box](quotas.metric,quotas.limit,quotas.usage)" 2>/dev/null \
        | grep -E "(METRIC|CPUS|cpus)" | head -20
    
    echo ""
}

# Function to show summary of all regions
show_all_regions() {
    echo -e "${GREEN}Fetching CPU quotas for all regions...${NC}"
    echo ""
    
    # Get list of regions
    regions=$(gcloud compute regions list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null)
    
    # Header
    printf "%-20s %10s %10s %10s %10s %10s %10s\n" \
        "REGION" "CPUS" "USED" "N2_CPUS" "USED" "E2_CPUS" "USED"
    printf "%-20s %10s %10s %10s %10s %10s %10s\n" \
        "--------------------" "----------" "----------" "----------" "----------" "----------" "----------"
    
    for region in $regions; do
        # Get quotas for this region
        quota_data=$(gcloud compute regions describe "$region" --project="$PROJECT_ID" \
            --format="json(quotas)" 2>/dev/null)
        
        # Extract specific quotas
        cpus_limit=$(echo "$quota_data" | jq -r '.quotas[] | select(.metric=="CPUS") | .limit // 0')
        cpus_usage=$(echo "$quota_data" | jq -r '.quotas[] | select(.metric=="CPUS") | .usage // 0')
        n2_limit=$(echo "$quota_data" | jq -r '.quotas[] | select(.metric=="N2_CPUS") | .limit // 0')
        n2_usage=$(echo "$quota_data" | jq -r '.quotas[] | select(.metric=="N2_CPUS") | .usage // 0')
        e2_limit=$(echo "$quota_data" | jq -r '.quotas[] | select(.metric=="E2_CPUS") | .limit // 0')
        e2_usage=$(echo "$quota_data" | jq -r '.quotas[] | select(.metric=="E2_CPUS") | .usage // 0')
        
        # Color based on availability (handle floats)
        n2_avail=$(echo "$n2_limit - $n2_usage" | bc 2>/dev/null || echo 0)
        e2_avail=$(echo "$e2_limit - $e2_usage" | bc 2>/dev/null || echo 0)

        if (( $(echo "$n2_avail >= 16" | bc -l) )); then
            color=$GREEN
        elif (( $(echo "$e2_avail >= 16" | bc -l) )); then
            color=$YELLOW
        elif (( $(echo "$n2_avail >= 8" | bc -l) )) || (( $(echo "$e2_avail >= 8" | bc -l) )); then
            color=$YELLOW
        else
            color=$RED
        fi
        
        printf "${color}%-20s %10.0f %10.0f %10.0f %10.0f %10.0f %10.0f${NC}\n" \
            "$region" "$cpus_limit" "$cpus_usage" "$n2_limit" "$n2_usage" "$e2_limit" "$e2_usage"
    done
}

# Function to show detailed quota for one region
show_region_detail() {
    local region=$1
    echo -e "${GREEN}Detailed quotas for region: $region${NC}"
    echo ""

    # Get quotas as JSON and format nicely
    quota_data=$(gcloud compute regions describe "$region" --project="$PROJECT_ID" \
        --format="json(quotas)" 2>/dev/null)

    echo "CPU Quotas:"
    echo "-----------"
    for metric in CPUS N2_CPUS E2_CPUS C2_CPUS C3_CPUS N2D_CPUS PREEMPTIBLE_CPUS; do
        limit=$(echo "$quota_data" | jq -r ".quotas[] | select(.metric==\"$metric\") | .limit // 0")
        usage=$(echo "$quota_data" | jq -r ".quotas[] | select(.metric==\"$metric\") | .usage // 0")
        avail=$(echo "$limit - $usage" | bc 2>/dev/null || echo 0)
        if [ -n "$limit" ] && [ "$limit" != "0" ]; then
            printf "  %-20s Limit: %8.0f  Used: %8.0f  Available: %8.0f\n" "$metric" "$limit" "$usage" "$avail"
        fi
    done

    echo ""
    echo "Storage Quotas:"
    echo "---------------"
    for metric in SSD_TOTAL_GB DISKS_TOTAL_GB LOCAL_SSD_TOTAL_GB; do
        limit=$(echo "$quota_data" | jq -r ".quotas[] | select(.metric==\"$metric\") | .limit // 0")
        usage=$(echo "$quota_data" | jq -r ".quotas[] | select(.metric==\"$metric\") | .usage // 0")
        avail=$(echo "$limit - $usage" | bc 2>/dev/null || echo 0)
        if [ -n "$limit" ] && [ "$limit" != "0" ]; then
            printf "  %-20s Limit: %8.0f  Used: %8.0f  Available: %8.0f\n" "$metric" "$limit" "$usage" "$avail"
        fi
    done

    echo ""
    echo -e "${BLUE}Machine type recommendations:${NC}"
    echo "  - n2-standard-2  = 2 vCPUs  (cluster + bastion = 4 vCPUs minimum)"
    echo "  - n2-standard-4  = 4 vCPUs  (cluster + bastion = 8 vCPUs)"
    echo "  - n2-standard-8  = 8 vCPUs  (cluster + bastion = 16 vCPUs)"
    echo "  - e2-standard-2  = 2 vCPUs  (cheaper, uses E2_CPUS quota)"
    echo "  - e2-standard-4  = 4 vCPUs  (cheaper, uses E2_CPUS quota)"
    echo ""
    echo -e "${YELLOW}For a 3-node cluster + bastion (4 VMs), you need:${NC}"
    echo "  - With n2-standard-2: 4 × 2 =  8 N2_CPUS"
    echo "  - With n2-standard-4: 4 × 4 = 16 N2_CPUS"
    echo "  - With e2-standard-4: 4 × 4 = 16 E2_CPUS"
}

# Main
if [ -n "$1" ]; then
    # Show detail for specific region
    show_region_detail "$1"
else
    # Show all regions summary
    show_all_regions
    echo ""
    echo -e "${BLUE}Usage: $0 <region> for detailed view${NC}"
    echo -e "${BLUE}Example: $0 europe-west1${NC}"
fi

