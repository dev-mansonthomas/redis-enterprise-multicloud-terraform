#!/bin/bash
# =============================================================================
# Azure-specific functions for Terramine deployment scripts
# =============================================================================

# Source common functions if not already loaded
if [ -z "$COMMON_LOADED" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/../common.sh"
fi

# -----------------------------------------------------------------------------
# Check Azure credentials
# -----------------------------------------------------------------------------
check_azure_credentials() {
    echo "Checking Azure credentials..."
    
    # Azure uses environment variables or az login, no file check needed
    if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
        log_warn "AZURE_SUBSCRIPTION_ID is not set. Make sure you're logged in with 'az login'."
    else
        log_info "Azure subscription ID configured"
    fi
    
    if [ -z "$AZURE_TENANT_ID" ]; then
        log_warn "AZURE_TENANT_ID is not set."
    else
        log_info "Azure tenant ID configured"
    fi
    
    return 0
}

# -----------------------------------------------------------------------------
# Build Azure-specific Terraform variables
# Supports two authentication methods:
# 1. Service Principal (AZURE_CLIENT_ID + AZURE_CLIENT_SECRET + AZURE_TENANT_ID)
# 2. Azure CLI (az login) - used when Service Principal credentials are not set
# -----------------------------------------------------------------------------
build_azure_vars() {
    # Azure requires at minimum subscription_id
    if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
        log_error "AZURE_SUBSCRIPTION_ID is not set in .env file."
        return 1
    fi

    VAR_ARGS="$VAR_ARGS -var=\"azure_subscription_id=$AZURE_SUBSCRIPTION_ID\""

    # Check authentication mode: Service Principal or Azure CLI
    if [ -n "$AZURE_CLIENT_ID" ] && [ -n "$AZURE_CLIENT_SECRET" ] && [ -n "$AZURE_TENANT_ID" ]; then
        # Service Principal authentication
        log_info "Using Service Principal authentication"
        VAR_ARGS="$VAR_ARGS -var=\"azure_tenant_id=$AZURE_TENANT_ID\""
        VAR_ARGS="$VAR_ARGS -var=\"azure_access_key_id=$AZURE_CLIENT_ID\""
        VAR_ARGS="$VAR_ARGS -var=\"azure_secret_key=$AZURE_CLIENT_SECRET\""
        VAR_ARGS="$VAR_ARGS -var=\"use_cli_auth=false\""
    else
        # Azure CLI authentication - verify az login
        log_info "Using Azure CLI authentication (az login)"
        if ! az account show &>/dev/null; then
            log_error "Not logged in to Azure CLI. Please run 'az login' first."
            return 1
        fi
        VAR_ARGS="$VAR_ARGS -var=\"use_cli_auth=true\""
        # Get tenant_id from az account if not set
        if [ -z "$AZURE_TENANT_ID" ]; then
            AZURE_TENANT_ID=$(az account show --query tenantId -o tsv 2>/dev/null)
        fi
        if [ -n "$AZURE_TENANT_ID" ]; then
            VAR_ARGS="$VAR_ARGS -var=\"azure_tenant_id=$AZURE_TENANT_ID\""
        fi
    fi

    # Add Azure-specific configuration
    if [ -n "$AZ_REGION_NAME" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"region_name=$AZ_REGION_NAME\""
    fi
    if [ -n "$AZ_VOLUME_TYPE" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"volume_type=$AZ_VOLUME_TYPE\""
    fi
    if [ -n "$AZ_MACHINE_TYPE" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"machine_type=$AZ_MACHINE_TYPE\""
    fi
    if [ -n "$AZ_BASTION_MACHINE_TYPE" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"bastion_machine_type=$AZ_BASTION_MACHINE_TYPE\""
    fi
    if [ -n "$AZ_MACHINE_IMAGE" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"machine_image=$AZ_MACHINE_IMAGE\""
    fi
    if [ -n "$AZ_HOSTED_ZONE" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"hosted_zone=$AZ_HOSTED_ZONE\""
    fi

    export VAR_ARGS
    return 0
}

# -----------------------------------------------------------------------------
# Full Azure pre-flight checks
# -----------------------------------------------------------------------------
preflight_azure() {
    echo ""
    log_header "Azure Pre-flight Checks"
    
    check_common_vars || return 1
    check_ssh_key || return 1
    check_azure_credentials || return 1
    
    echo ""
    log_info "All Azure pre-flight checks passed"
    return 0
}

