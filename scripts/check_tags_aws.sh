#!/bin/bash
# =============================================================================
# AWS Tag Verification Script
# =============================================================================
# Checks that all resources created by Terraform have:
#   - owner tag
#   - skip_deletion tag
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$ROOT_DIR/.env" ]; then
    source "$ROOT_DIR/.env"
fi

# Load AWS credentials if specified
if [ -n "$AWS_CREDENTIALS_FILE" ] && [ -f "$AWS_CREDENTIALS_FILE" ]; then
    source "$AWS_CREDENTIALS_FILE"
fi

OWNER="${OWNER:-}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-}"

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}AWS Tag Verification${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

if [ -z "$OWNER" ]; then
    echo -e "${YELLOW}Warning: OWNER not set in .env${NC}"
    read -p "Enter owner tag to search for: " OWNER
fi

echo -e "Searching for resources with owner=${GREEN}$OWNER${NC}"
echo ""

# Resource types to check
RESOURCE_TYPES=(
    "ec2:instance"
    "ec2:volume"
    "ec2:security-group"
    "ec2:vpc"
    "ec2:subnet"
    "ec2:internet-gateway"
    "ec2:natgateway"
    "ec2:route-table"
    "ec2:network-interface"
    "ec2:elastic-ip"
    "ec2:vpc-peering-connection"
    "ec2:key-pair"
    "elasticloadbalancing:loadbalancer"
    "rds:db"
    "s3:bucket"
)

MISSING_TAGS=0
TOTAL_RESOURCES=0

# Function to check resources
check_resources() {
    local resource_type=$1
    echo -e "${BLUE}Checking ${resource_type}...${NC}"
    
    # Get resources with owner tag
    resources=$(aws resourcegroupstaggingapi get-resources \
        --tag-filters "Key=owner,Values=$OWNER" \
        --resource-type-filters "$resource_type" \
        --query 'ResourceTagMappingList[*].[ResourceARN,Tags]' \
        --output json 2>/dev/null || echo "[]")
    
    if [ "$resources" == "[]" ] || [ -z "$resources" ]; then
        echo -e "  ${YELLOW}No resources found${NC}"
        return
    fi
    
    # Parse and check each resource
    echo "$resources" | jq -c '.[]' 2>/dev/null | while read -r resource; do
        arn=$(echo "$resource" | jq -r '.[0]')
        tags=$(echo "$resource" | jq -r '.[1]')
        
        TOTAL_RESOURCES=$((TOTAL_RESOURCES + 1))
        
        # Check for skip_deletion tag
        has_skip_deletion=$(echo "$tags" | jq -r '.[] | select(.Key=="skip_deletion") | .Value' 2>/dev/null)
        has_owner=$(echo "$tags" | jq -r '.[] | select(.Key=="owner") | .Value' 2>/dev/null)
        
        # Extract resource name/id from ARN
        resource_name=$(echo "$arn" | awk -F'/' '{print $NF}' | awk -F':' '{print $NF}')
        
        if [ -z "$has_skip_deletion" ]; then
            echo -e "  ${RED}✗ MISSING skip_deletion:${NC} $resource_name"
            echo -e "    ARN: $arn"
            MISSING_TAGS=$((MISSING_TAGS + 1))
        elif [ -z "$has_owner" ]; then
            echo -e "  ${RED}✗ MISSING owner:${NC} $resource_name"
            echo -e "    ARN: $arn"
            MISSING_TAGS=$((MISSING_TAGS + 1))
        else
            echo -e "  ${GREEN}✓${NC} $resource_name (owner=$has_owner, skip_deletion=$has_skip_deletion)"
        fi
    done
}

# Check all resource types
for rt in "${RESOURCE_TYPES[@]}"; do
    check_resources "$rt"
    echo ""
done

# Also check with deployment name if set
if [ -n "$DEPLOYMENT_NAME" ]; then
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}Checking resources by Name tag pattern: *${DEPLOYMENT_NAME}*${NC}"
    echo -e "${BLUE}==========================================${NC}"
    
    aws resourcegroupstaggingapi get-resources \
        --tag-filters "Key=Name,Values=*${DEPLOYMENT_NAME}*" \
        --query 'ResourceTagMappingList[*].[ResourceARN,Tags]' \
        --output json 2>/dev/null | jq -c '.[]' 2>/dev/null | while read -r resource; do
        arn=$(echo "$resource" | jq -r '.[0]')
        tags=$(echo "$resource" | jq -r '.[1]')
        
        has_skip_deletion=$(echo "$tags" | jq -r '.[] | select(.Key=="skip_deletion") | .Value' 2>/dev/null)
        has_owner=$(echo "$tags" | jq -r '.[] | select(.Key=="owner") | .Value' 2>/dev/null)
        resource_name=$(echo "$arn" | awk -F'/' '{print $NF}' | awk -F':' '{print $NF}')
        
        if [ -z "$has_skip_deletion" ] || [ -z "$has_owner" ]; then
            echo -e "${RED}✗ MISSING TAGS:${NC} $resource_name"
            echo -e "  owner=${has_owner:-MISSING}, skip_deletion=${has_skip_deletion:-MISSING}"
            echo -e "  ARN: $arn"
        fi
    done
fi

echo ""
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "Resources checked with owner=${GREEN}$OWNER${NC}"
echo ""
echo -e "To list ALL resources by owner:"
echo -e "  aws resourcegroupstaggingapi get-resources --tag-filters Key=owner,Values=$OWNER"

