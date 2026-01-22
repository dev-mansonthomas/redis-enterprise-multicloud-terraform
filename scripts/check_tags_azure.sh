#!/bin/bash
# =============================================================================
# Azure Tag Verification Script
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

OWNER="${OWNER:-}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-}"

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Azure Tag Verification${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

if [ -z "$OWNER" ]; then
    echo -e "${YELLOW}Warning: OWNER not set in .env${NC}"
    read -p "Enter owner tag to search for: " OWNER
fi

echo -e "Searching for resources with owner=${GREEN}$OWNER${NC}"
echo ""

# Check if logged in
if ! az account show &>/dev/null; then
    echo -e "${RED}Error: Not logged into Azure. Run 'az login' first.${NC}"
    exit 1
fi

SUBSCRIPTION=$(az account show --query id -o tsv)
echo -e "Subscription: ${GREEN}$SUBSCRIPTION${NC}"
echo ""

MISSING_TAGS=0
TOTAL_RESOURCES=0

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Resources with owner=$OWNER${NC}"
echo -e "${BLUE}==========================================${NC}"

# Get all resources with owner tag
resources=$(az resource list --tag "owner=$OWNER" --query '[].{id:id, name:name, type:type, tags:tags}' -o json 2>/dev/null)

if [ "$resources" == "[]" ] || [ -z "$resources" ]; then
    echo -e "${YELLOW}No resources found with owner=$OWNER${NC}"
else
    echo "$resources" | jq -c '.[]' | while read -r resource; do
        name=$(echo "$resource" | jq -r '.name')
        type=$(echo "$resource" | jq -r '.type')
        id=$(echo "$resource" | jq -r '.id')
        tags=$(echo "$resource" | jq -r '.tags')
        
        TOTAL_RESOURCES=$((TOTAL_RESOURCES + 1))
        
        has_skip_deletion=$(echo "$tags" | jq -r '.skip_deletion // empty' 2>/dev/null)
        has_owner=$(echo "$tags" | jq -r '.owner // empty' 2>/dev/null)
        
        # Simplify type for display
        short_type=$(echo "$type" | awk -F'/' '{print $NF}')
        
        if [ -z "$has_skip_deletion" ]; then
            echo -e "${RED}✗ MISSING skip_deletion:${NC}"
            echo -e "  Name: $name"
            echo -e "  Type: $short_type"
            echo -e "  ID: $id"
            MISSING_TAGS=$((MISSING_TAGS + 1))
        else
            echo -e "${GREEN}✓${NC} $name ($short_type)"
            echo -e "  owner=$has_owner, skip_deletion=$has_skip_deletion"
        fi
        echo ""
    done
fi

# Also search by resource group name pattern
if [ -n "$DEPLOYMENT_NAME" ]; then
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}Resource Groups matching: *${DEPLOYMENT_NAME}*${NC}"
    echo -e "${BLUE}==========================================${NC}"
    
    az group list --query "[?contains(name, '$DEPLOYMENT_NAME')].{name:name, tags:tags}" -o json 2>/dev/null | jq -c '.[]' | while read -r rg; do
        name=$(echo "$rg" | jq -r '.name')
        tags=$(echo "$rg" | jq -r '.tags // {}')
        
        has_skip_deletion=$(echo "$tags" | jq -r '.skip_deletion // empty' 2>/dev/null)
        has_owner=$(echo "$tags" | jq -r '.owner // empty' 2>/dev/null)
        
        if [ -z "$has_skip_deletion" ] || [ -z "$has_owner" ]; then
            echo -e "${RED}✗ Resource Group MISSING TAGS:${NC} $name"
            echo -e "  owner=${has_owner:-MISSING}, skip_deletion=${has_skip_deletion:-MISSING}"
        else
            echo -e "${GREEN}✓${NC} Resource Group: $name"
            echo -e "  owner=$has_owner, skip_deletion=$has_skip_deletion"
        fi
        
        # List resources in this RG
        echo -e "  Resources in this group:"
        az resource list -g "$name" --query '[].{name:name, type:type, tags:tags}' -o json 2>/dev/null | jq -c '.[]' | while read -r res; do
            res_name=$(echo "$res" | jq -r '.name')
            res_type=$(echo "$res" | jq -r '.type' | awk -F'/' '{print $NF}')
            res_tags=$(echo "$res" | jq -r '.tags // {}')
            
            res_skip=$(echo "$res_tags" | jq -r '.skip_deletion // empty' 2>/dev/null)
            res_owner=$(echo "$res_tags" | jq -r '.owner // empty' 2>/dev/null)
            
            if [ -z "$res_skip" ] || [ -z "$res_owner" ]; then
                echo -e "    ${RED}✗${NC} $res_name ($res_type) - owner=${res_owner:-MISSING}, skip_deletion=${res_skip:-MISSING}"
            else
                echo -e "    ${GREEN}✓${NC} $res_name ($res_type)"
            fi
        done
        echo ""
    done
fi

echo ""
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "To list ALL resources by owner:"
echo -e "  az resource list --tag owner=$OWNER -o table"

