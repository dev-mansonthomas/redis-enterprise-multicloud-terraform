#!/bin/bash
# =============================================================================
# GCP Label Verification Script
# =============================================================================
# Checks that all resources created by Terraform have:
#   - owner label
#   - skip_deletion label
# Note: GCP uses "labels" instead of "tags"
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

# Set GCP credentials if specified
if [ -n "$GCP_CREDENTIALS_FILE" ] && [ -f "$GCP_CREDENTIALS_FILE" ]; then
    export GOOGLE_APPLICATION_CREDENTIALS="$GCP_CREDENTIALS_FILE"
fi

OWNER="${OWNER:-}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-}"
GCP_PROJECT="${GCP_PROJECT:-}"

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}GCP Label Verification${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

if [ -z "$OWNER" ]; then
    echo -e "${YELLOW}Warning: OWNER not set in .env${NC}"
    read -p "Enter owner label to search for: " OWNER
fi

# GCP labels must be lowercase (keep underscores, GCP accepts them)
OWNER_LABEL=$(echo "$OWNER" | tr '[:upper:]' '[:lower:]')

if [ -z "$GCP_PROJECT" ]; then
    GCP_PROJECT=$(gcloud config get-value project 2>/dev/null)
fi

echo -e "Project: ${GREEN}$GCP_PROJECT${NC}"
echo -e "Searching for resources with owner=${GREEN}$OWNER_LABEL${NC}"
echo ""

MISSING_LABELS=0

# Function to check compute instances
check_instances() {
    echo -e "${BLUE}Checking Compute Instances...${NC}"
    
    instances=$(gcloud compute instances list \
        --project="$GCP_PROJECT" \
        --filter="labels.owner=$OWNER_LABEL" \
        --format="json" 2>/dev/null)
    
    if [ "$instances" == "[]" ] || [ -z "$instances" ]; then
        echo -e "  ${YELLOW}No instances found${NC}"
        return
    fi
    
    echo "$instances" | jq -c '.[]' | while read -r instance; do
        name=$(echo "$instance" | jq -r '.name')
        zone=$(echo "$instance" | jq -r '.zone' | awk -F'/' '{print $NF}')
        labels=$(echo "$instance" | jq -r '.labels // {}')
        
        has_skip=$(echo "$labels" | jq -r '.skip_deletion // empty')
        has_owner=$(echo "$labels" | jq -r '.owner // empty')
        
        if [ -z "$has_skip" ]; then
            echo -e "  ${RED}✗ MISSING skip_deletion:${NC} $name (zone: $zone)"
            MISSING_LABELS=$((MISSING_LABELS + 1))
        else
            echo -e "  ${GREEN}✓${NC} $name (zone: $zone) - owner=$has_owner, skip_deletion=$has_skip"
        fi
    done
}

# Function to check disks
check_disks() {
    echo -e "${BLUE}Checking Compute Disks...${NC}"

    # Search by name pattern if DEPLOYMENT_NAME is set
    local filter="labels.owner=$OWNER_LABEL"
    if [ -n "$DEPLOYMENT_NAME" ]; then
        filter="name~$DEPLOYMENT_NAME"
    fi

    disks=$(gcloud compute disks list \
        --project="$GCP_PROJECT" \
        --filter="$filter" \
        --format="json" 2>/dev/null)

    if [ "$disks" == "[]" ] || [ -z "$disks" ]; then
        echo -e "  ${YELLOW}No disks found${NC}"
        return
    fi

    echo "$disks" | jq -c '.[]' | while read -r disk; do
        name=$(echo "$disk" | jq -r '.name')
        zone=$(echo "$disk" | jq -r '.zone' | awk -F'/' '{print $NF}')
        labels=$(echo "$disk" | jq -r '.labels // {}')

        has_skip=$(echo "$labels" | jq -r '.skip_deletion // empty')
        has_owner=$(echo "$labels" | jq -r '.owner // empty')

        if [ -z "$has_skip" ] || [ -z "$has_owner" ]; then
            echo -e "  ${RED}✗ MISSING LABELS:${NC} $name (zone: $zone)"
            echo -e "    owner=${has_owner:-MISSING}, skip_deletion=${has_skip:-MISSING}"
        else
            echo -e "  ${GREEN}✓${NC} $name (zone: $zone) - owner=$has_owner, skip_deletion=$has_skip"
        fi
    done
}

# Function to check static IP addresses
check_addresses() {
    echo -e "${BLUE}Checking Static IP Addresses...${NC}"

    # Search by name pattern if DEPLOYMENT_NAME is set
    local filter="labels.owner=$OWNER_LABEL"
    if [ -n "$DEPLOYMENT_NAME" ]; then
        filter="name~$DEPLOYMENT_NAME"
    fi

    addresses=$(gcloud compute addresses list \
        --project="$GCP_PROJECT" \
        --filter="$filter" \
        --format="json" 2>/dev/null)

    if [ "$addresses" == "[]" ] || [ -z "$addresses" ]; then
        echo -e "  ${YELLOW}No static IP addresses found${NC}"
        return
    fi

    echo "$addresses" | jq -c '.[]' | while read -r addr; do
        name=$(echo "$addr" | jq -r '.name')
        region=$(echo "$addr" | jq -r '.region // "global"' | awk -F'/' '{print $NF}')
        labels=$(echo "$addr" | jq -r '.labels // {}')

        has_skip=$(echo "$labels" | jq -r '.skip_deletion // empty')
        has_owner=$(echo "$labels" | jq -r '.owner // empty')

        if [ -z "$has_skip" ] || [ -z "$has_owner" ]; then
            echo -e "  ${RED}✗ MISSING LABELS:${NC} $name (region: $region)"
            echo -e "    owner=${has_owner:-MISSING}, skip_deletion=${has_skip:-MISSING}"
        else
            echo -e "  ${GREEN}✓${NC} $name (region: $region) - owner=$has_owner, skip_deletion=$has_skip"
        fi
    done
}

# Function to check VPCs
check_vpcs() {
    echo -e "${BLUE}Checking VPC Networks...${NC}"
    
    # VPCs don't support labels directly, check by name pattern
    if [ -n "$DEPLOYMENT_NAME" ]; then
        vpcs=$(gcloud compute networks list \
            --project="$GCP_PROJECT" \
            --filter="name~$DEPLOYMENT_NAME" \
            --format="json" 2>/dev/null)
        
        if [ "$vpcs" == "[]" ] || [ -z "$vpcs" ]; then
            echo -e "  ${YELLOW}No VPCs found matching $DEPLOYMENT_NAME${NC}"
            return
        fi
        
        echo "$vpcs" | jq -c '.[]' | while read -r vpc; do
            name=$(echo "$vpc" | jq -r '.name')
            echo -e "  ${YELLOW}⚠${NC} $name (VPCs don't support labels in GCP)"
        done
    fi
}

# Function to check firewall rules
check_firewalls() {
    echo -e "${BLUE}Checking Firewall Rules...${NC}"
    
    if [ -n "$DEPLOYMENT_NAME" ]; then
        rules=$(gcloud compute firewall-rules list \
            --project="$GCP_PROJECT" \
            --filter="name~$DEPLOYMENT_NAME" \
            --format="json" 2>/dev/null)
        
        if [ "$rules" == "[]" ] || [ -z "$rules" ]; then
            echo -e "  ${YELLOW}No firewall rules found matching $DEPLOYMENT_NAME${NC}"
            return
        fi
        
        echo "$rules" | jq -c '.[]' | while read -r rule; do
            name=$(echo "$rule" | jq -r '.name')
            echo -e "  ${YELLOW}⚠${NC} $name (Firewall rules don't support labels)"
        done
    fi
}

# Run checks
check_instances
echo ""
check_disks
echo ""
check_addresses
echo ""
check_vpcs
echo ""
check_firewalls
echo ""

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "Checked resources with owner=${GREEN}$OWNER_LABEL${NC}"
echo ""
echo -e "${YELLOW}Note: Some GCP resources (VPCs, Firewall rules) don't support labels.${NC}"
echo ""
echo -e "To list ALL instances by owner:"
echo -e "  gcloud compute instances list --filter='labels.owner=$OWNER_LABEL'"

