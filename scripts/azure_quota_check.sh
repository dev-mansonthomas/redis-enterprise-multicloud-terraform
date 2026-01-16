#!/bin/bash
# =============================================================================
# Azure Quota Check Utility
# Lists available vCPU quotas by region to help choose the right region/VM size
# Usage: ./scripts/azure_quota_check.sh [region]
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

# Check Azure CLI
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI (az) not found${NC}"
    echo "Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Get subscription
SUBSCRIPTION_ID="${AZ_SUBSCRIPTION_ID:-$(az account show --query id -o tsv 2>/dev/null)}"
SUBSCRIPTION_NAME=$(az account show --query name -o tsv 2>/dev/null)

if [ -z "$SUBSCRIPTION_ID" ]; then
    echo -e "${RED}Error: No Azure subscription configured${NC}"
    echo "Run: az login"
    exit 1
fi

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Azure vCPU Quota Check${NC}"
echo -e "${BLUE}Subscription: $SUBSCRIPTION_NAME${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Function to get quota for a specific region
get_region_quota() {
    local region=$1
    echo -e "${GREEN}Detailed quotas for region: $region${NC}"
    echo ""
    
    echo "VM Family Quotas (vCPUs):"
    echo "-------------------------"
    
    # Get all compute quotas for the region
    az vm list-usage --location "$region" -o json 2>/dev/null | jq -r '
        .[] | 
        select(.name.value | test("DSv5|DSv4|DSv3|ESv5|ESv4|Standard")) |
        select(.currentValue > 0 or .limit > 0) |
        "\(.name.localizedValue)|\(.currentValue)|\(.limit)"
    ' | while IFS='|' read -r name used limit; do
        avail=$((limit - used))
        if [ "$avail" -ge 16 ]; then
            color=$GREEN
        elif [ "$avail" -ge 8 ]; then
            color=$YELLOW
        else
            color=$RED
        fi
        printf "${color}  %-45s Used: %4d / %-4d  Available: %4d${NC}\n" "$name" "$used" "$limit" "$avail"
    done
    
    echo ""
    echo -e "${BLUE}VM size recommendations for Redis Enterprise:${NC}"
    echo "  - Standard_D2s_v5  = 2 vCPUs, 8GB   (uses standardDSv5Family)"
    echo "  - Standard_D4s_v5  = 4 vCPUs, 16GB  (uses standardDSv5Family)"
    echo "  - Standard_D8s_v5  = 8 vCPUs, 32GB  (uses standardDSv5Family)"
    echo "  - Standard_E4s_v5  = 4 vCPUs, 32GB  (uses standardESv5Family, memory-optimized)"
    echo ""
    echo -e "${YELLOW}For a 3-node cluster + bastion (4 VMs), you need:${NC}"
    echo "  - With Standard_D2s_v5: 4 × 2 =  8 vCPUs in standardDSv5Family"
    echo "  - With Standard_D4s_v5: 4 × 4 = 16 vCPUs in standardDSv5Family"
}

# Function to show summary of all regions
show_all_regions() {
    echo -e "${GREEN}Fetching vCPU quotas for common regions...${NC}"
    echo -e "${YELLOW}(This may take a minute)${NC}"
    echo ""
    
    # Common Azure regions
    regions=(
        "westeurope" "northeurope" "francecentral" "germanywestcentral" "uksouth"
        "eastus" "eastus2" "westus" "westus2" "centralus"
        "southeastasia" "eastasia" "australiaeast"
    )
    
    # Header
    printf "%-20s %12s %12s %12s %12s\n" \
        "REGION" "DSv5_LIMIT" "DSv5_AVAIL" "ESv5_LIMIT" "ESv5_AVAIL"
    printf "%-20s %12s %12s %12s %12s\n" \
        "--------------------" "------------" "------------" "------------" "------------"
    
    for region in "${regions[@]}"; do
        # Get quotas for DSv5 and ESv5 families
        quota_data=$(az vm list-usage --location "$region" -o json 2>/dev/null || echo "[]")
        
        dsv5_limit=$(echo "$quota_data" | jq -r '.[] | select(.name.value=="standardDSv5Family") | .limit // 0')
        dsv5_used=$(echo "$quota_data" | jq -r '.[] | select(.name.value=="standardDSv5Family") | .currentValue // 0')
        dsv5_avail=$((${dsv5_limit:-0} - ${dsv5_used:-0}))
        
        esv5_limit=$(echo "$quota_data" | jq -r '.[] | select(.name.value=="standardESv5Family") | .limit // 0')
        esv5_used=$(echo "$quota_data" | jq -r '.[] | select(.name.value=="standardESv5Family") | .currentValue // 0')
        esv5_avail=$((${esv5_limit:-0} - ${esv5_used:-0}))
        
        # Color based on availability
        if [ "${dsv5_avail:-0}" -ge 16 ] || [ "${esv5_avail:-0}" -ge 16 ]; then
            color=$GREEN
        elif [ "${dsv5_avail:-0}" -ge 8 ] || [ "${esv5_avail:-0}" -ge 8 ]; then
            color=$YELLOW
        else
            color=$RED
        fi
        
        printf "${color}%-20s %12d %12d %12d %12d${NC}\n" \
            "$region" "${dsv5_limit:-0}" "${dsv5_avail:-0}" "${esv5_limit:-0}" "${esv5_avail:-0}"
    done
}

# Main
if [ -n "$1" ]; then
    get_region_quota "$1"
else
    show_all_regions
    echo ""
    echo -e "${BLUE}Usage: $0 <region> for detailed view${NC}"
    echo -e "${BLUE}Example: $0 westeurope${NC}"
    echo ""
    echo -e "${YELLOW}To request quota increase:${NC}"
    echo "  az quota update --resource-name standardDSv5Family --scope /subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Compute/locations/<region> --limit-value 16"
    echo "  Or visit: https://portal.azure.com/#view/Microsoft_Azure_Capacity/QuotaMenuBlade/~/myQuotas"
fi

