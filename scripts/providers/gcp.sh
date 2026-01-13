#!/bin/bash
# =============================================================================
# GCP-specific functions for Terramine deployment scripts
# =============================================================================

# Source common functions if not already loaded
if [ -z "$COMMON_LOADED" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/../common.sh"
fi

# -----------------------------------------------------------------------------
# Check GCP credentials
# -----------------------------------------------------------------------------
check_gcp_credentials() {
    echo "Checking GCP credentials..."
    
    if [ -z "$GCP_CREDENTIALS_FILE" ]; then
        log_error "GCP_CREDENTIALS_FILE is not set in .env file."
        return 1
    fi
    
    # Expand tilde if present
    local expanded_file="${GCP_CREDENTIALS_FILE/#\~/$HOME}"
    if [ ! -f "$expanded_file" ]; then
        log_error "GCP credentials file not found: $GCP_CREDENTIALS_FILE"
        echo "Please check GCP_CREDENTIALS_FILE in your .env file."
        return 1
    fi
    
    log_info "GCP credentials: $GCP_CREDENTIALS_FILE"
    
    # Check GCP project ID
    if [ -z "$GCP_PROJECT_ID" ]; then
        log_warn "GCP_PROJECT_ID is not set. Make sure it's defined in your Terraform variables."
    else
        log_info "GCP project: $GCP_PROJECT_ID"
    fi
    
    return 0
}

# -----------------------------------------------------------------------------
# Build GCP-specific Terraform variables
# -----------------------------------------------------------------------------
build_gcp_vars() {
    # Add GCP credentials
    VAR_ARGS="$VAR_ARGS -var=\"credentials=$GCP_CREDENTIALS_FILE\""
    
    if [ -n "$GCP_PROJECT_ID" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"project=$GCP_PROJECT_ID\""
    fi

    # Add GCP-specific configuration
    if [ -n "$GCP_REGION_NAME" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"region_name=$GCP_REGION_NAME\""
    fi
    if [ -n "$GCP_MACHINE_TYPE" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"machine_type=$GCP_MACHINE_TYPE\""
    fi
    if [ -n "$GCP_BASTION_MACHINE_TYPE" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"bastion_machine_type=$GCP_BASTION_MACHINE_TYPE\""
    fi
    if [ -n "$GCP_MACHINE_IMAGE" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"machine_image=$GCP_MACHINE_IMAGE\""
    fi
    if [ -n "$GCP_HOSTED_ZONE" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"hosted_zone=$GCP_HOSTED_ZONE\""
    fi
    if [ -n "$GCP_HOSTED_ZONE_NAME" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"hosted_zone_name=$GCP_HOSTED_ZONE_NAME\""
    fi
    
    export VAR_ARGS
    return 0
}

# -----------------------------------------------------------------------------
# Full GCP pre-flight checks
# -----------------------------------------------------------------------------
preflight_gcp() {
    echo ""
    log_header "GCP Pre-flight Checks"
    
    check_common_vars || return 1
    check_ssh_key || return 1
    check_gcp_credentials || return 1
    
    echo ""
    log_info "All GCP pre-flight checks passed"
    return 0
}

