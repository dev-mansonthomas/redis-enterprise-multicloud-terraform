#!/bin/bash
# =============================================================================
# AWS-specific functions for Terramine deployment scripts
# =============================================================================

# Source common functions if not already loaded
if [ -z "$COMMON_LOADED" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/../common.sh"
fi

# -----------------------------------------------------------------------------
# Check AWS credentials
# -----------------------------------------------------------------------------
check_aws_credentials() {
    echo "Checking AWS credentials..."
    
    # Check AWS credentials file
    if [ -n "$AWS_CREDENTIALS_FILE" ]; then
        # Expand tilde if present
        local expanded_file="${AWS_CREDENTIALS_FILE/#\~/$HOME}"
        if [ ! -f "$expanded_file" ]; then
            log_error "AWS credentials file not found: $AWS_CREDENTIALS_FILE"
            echo "Please check AWS_CREDENTIALS_FILE in your .env file."
            return 1
        fi
        log_info "AWS credentials: $AWS_CREDENTIALS_FILE"
    elif [ -f ~/.cred/aws.sh ]; then
        log_info "AWS credentials: ~/.cred/aws.sh (default)"
    else
        log_warn "No AWS credentials file found. Will use environment variables or AWS CLI profile."
    fi
    
    return 0
}

# -----------------------------------------------------------------------------
# Load AWS credentials
# -----------------------------------------------------------------------------
load_aws_credentials() {
    if [ -n "$AWS_CREDENTIALS_FILE" ] && [ -f "${AWS_CREDENTIALS_FILE/#\~/$HOME}" ]; then
        echo "Loading AWS credentials from $AWS_CREDENTIALS_FILE..."
        # shellcheck source=/dev/null
        source "${AWS_CREDENTIALS_FILE/#\~/$HOME}"
    elif [ -f ~/.cred/aws.sh ]; then
        echo "Loading AWS credentials from ~/.cred/aws.sh..."
        # shellcheck source=/dev/null
        source ~/.cred/aws.sh
    fi

    # Support both old (KEY/SEC) and new (AWS_ACCESS_KEY/AWS_SECRET_KEY) variable names
    AWS_KEY="${AWS_ACCESS_KEY:-$KEY}"
    AWS_SEC="${AWS_SECRET_KEY:-$SEC}"

    if [ -z "$AWS_KEY" ] || [ -z "$AWS_SEC" ]; then
        log_error "AWS credentials are not set."
        return 1
    fi
    
    export AWS_KEY AWS_SEC
    return 0
}

# -----------------------------------------------------------------------------
# Build AWS-specific Terraform variables
# -----------------------------------------------------------------------------
build_aws_vars() {
    # Load credentials first
    load_aws_credentials || return 1

    # Add AWS credentials
    VAR_ARGS="$VAR_ARGS -var=\"aws_access_key=$AWS_KEY\""
    VAR_ARGS="$VAR_ARGS -var=\"aws_secret_key=$AWS_SEC\""

    # Add AWS-specific configuration
    if [ -n "$AWS_REGION_NAME" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"region_name=$AWS_REGION_NAME\""
    fi
    if [ -n "$AWS_VOLUME_TYPE" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"volume_type=$AWS_VOLUME_TYPE\""
    fi
    if [ -n "$AWS_MACHINE_TYPE" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"machine_type=$AWS_MACHINE_TYPE\""
    fi
    if [ -n "$AWS_BASTION_MACHINE_TYPE" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"bastion_machine_type=$AWS_BASTION_MACHINE_TYPE\""
    fi
    if [ -n "$AWS_MACHINE_IMAGE" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"machine_image=$AWS_MACHINE_IMAGE\""
    fi
    if [ -n "$AWS_HOSTED_ZONE" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"hosted_zone=$AWS_HOSTED_ZONE\""
    fi

    export VAR_ARGS
    return 0
}

# -----------------------------------------------------------------------------
# Full AWS pre-flight checks
# -----------------------------------------------------------------------------
preflight_aws() {
    echo ""
    log_header "AWS Pre-flight Checks"
    
    check_common_vars || return 1
    check_ssh_key || return 1
    check_aws_credentials || return 1
    
    echo ""
    log_info "All AWS pre-flight checks passed"
    return 0
}

