#!/bin/bash
# =============================================================================
# AWS Quota Check Utility
# Lists available vCPU quotas by region to help choose the right region/instance
# Usage: ./scripts/aws_quota_check.sh [region]
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

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI (aws) not found${NC}"
    echo "Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Source AWS credentials if available
if [ -n "$AWS_CREDENTIALS_FILE" ] && [ -f "$AWS_CREDENTIALS_FILE" ]; then
    source "$AWS_CREDENTIALS_FILE"
    export AWS_ACCESS_KEY_ID="$KEY"
    export AWS_SECRET_ACCESS_KEY="$SEC"
fi

# Verify AWS access
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}Error: Cannot authenticate with AWS${NC}"
    echo "Configure AWS credentials in .env or run: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}AWS vCPU Quota Check - Account: $ACCOUNT_ID${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Function to get quota for a specific region
get_region_quota() {
    local region=$1
    echo -e "${GREEN}Detailed quotas for region: $region${NC}"
    echo ""
    
    echo "EC2 On-Demand vCPU Quotas:"
    echo "--------------------------"
    
    # Get service quotas for EC2
    aws service-quotas list-service-quotas \
        --service-code ec2 \
        --region "$region" \
        --query "Quotas[?contains(QuotaName, 'On-Demand')].{Name:QuotaName,Value:Value}" \
        --output table 2>/dev/null | head -30
    
    echo ""
    echo -e "${BLUE}Instance type recommendations for Redis Enterprise:${NC}"
    echo "  - t3.xlarge   = 4 vCPUs, 16GB   (uses Standard instances quota)"
    echo "  - t3.2xlarge  = 8 vCPUs, 32GB   (uses Standard instances quota)"
    echo "  - m6i.xlarge  = 4 vCPUs, 16GB   (uses Standard instances quota)"
    echo "  - i3.xlarge   = 4 vCPUs, 30GB   (uses Standard instances quota, has NVMe)"
    echo "  - i4i.xlarge  = 4 vCPUs, 32GB   (uses Standard instances quota, has NVMe)"
    echo ""
    echo -e "${YELLOW}For a 3-node cluster + bastion (4 VMs), you need:${NC}"
    echo "  - With t3.xlarge:  4 × 4 = 16 vCPUs"
    echo "  - With t3.2xlarge: 4 × 8 = 32 vCPUs"
}

# Function to show summary of common regions
show_all_regions() {
    echo -e "${GREEN}Fetching vCPU quotas for common regions...${NC}"
    echo -e "${YELLOW}(This may take a minute)${NC}"
    echo ""
    
    # Common AWS regions
    regions=(
        "us-east-1" "us-east-2" "us-west-1" "us-west-2"
        "eu-west-1" "eu-west-2" "eu-west-3" "eu-central-1"
        "ap-southeast-1" "ap-southeast-2" "ap-northeast-1"
    )
    
    # Header
    printf "%-15s %15s %15s\n" "REGION" "STANDARD_QUOTA" "STATUS"
    printf "%-15s %15s %15s\n" "---------------" "---------------" "---------------"
    
    for region in "${regions[@]}"; do
        # Get Standard instances quota (covers t3, m6i, etc.)
        quota=$(aws service-quotas get-service-quota \
            --service-code ec2 \
            --quota-code L-1216C47A \
            --region "$region" \
            --query "Quota.Value" \
            --output text 2>/dev/null || echo "N/A")
        
        # Color based on quota
        if [ "$quota" != "N/A" ]; then
            if (( $(echo "$quota >= 32" | bc -l 2>/dev/null || echo 0) )); then
                color=$GREEN
                status="✓ Good"
            elif (( $(echo "$quota >= 16" | bc -l 2>/dev/null || echo 0) )); then
                color=$YELLOW
                status="⚠ Limited"
            else
                color=$RED
                status="✗ Low"
            fi
        else
            color=$RED
            status="? Unknown"
        fi
        
        printf "${color}%-15s %15s %15s${NC}\n" "$region" "$quota" "$status"
    done
}

# Main
if [ -n "$1" ]; then
    get_region_quota "$1"
else
    show_all_regions
    echo ""
    echo -e "${BLUE}Usage: $0 <region> for detailed view${NC}"
    echo -e "${BLUE}Example: $0 us-east-1${NC}"
    echo ""
    echo -e "${YELLOW}To request quota increase:${NC}"
    echo "  aws service-quotas request-service-quota-increase \\"
    echo "    --service-code ec2 --quota-code L-1216C47A --desired-value 64 --region <region>"
    echo "  Or visit: https://console.aws.amazon.com/servicequotas/home/services/ec2/quotas"
fi

