#!/bin/bash
# =============================================================================
# Common functions for Terramine deployment scripts
# =============================================================================

# Mark as loaded to prevent double-sourcing
export COMMON_LOADED=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Logging functions
# -----------------------------------------------------------------------------
log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_header() {
    echo ""
    echo "========================================="
    echo "$1"
    echo "========================================="
}

# -----------------------------------------------------------------------------
# Load environment variables from .env file
# -----------------------------------------------------------------------------
load_env() {
    local project_root="${1:-$PROJECT_ROOT}"
    local env_file="$project_root/.env"
    
    if [ -f "$env_file" ]; then
        echo "Loading configuration from $env_file..."
        # shellcheck source=/dev/null
        source "$env_file"
        return 0
    else
        log_error "Error: .env file not found at: $env_file"
        echo "Please create a .env file at the project root with your configuration."
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Validate DEPLOYMENT_NAME format
# Used in DNS names, so only allow: letters, numbers, hyphens
# No underscores or dots allowed!
# -----------------------------------------------------------------------------
validate_deployment_name() {
    local name="$1"
    local pattern='^[-a-zA-Z0-9]+$'

    if [ -z "$name" ]; then
        log_error "DEPLOYMENT_NAME is not set. Please set it in .env file."
        return 1
    fi

    if [[ ! "$name" =~ $pattern ]]; then
        log_error "DEPLOYMENT_NAME '$name' contains invalid characters."
        echo "       Allowed pattern: ^[-a-zA-Z0-9]+$ (letters, numbers, hyphens only)"
        echo "       Underscores (_) and dots (.) are NOT allowed!"
        echo "       Example: 'my-project' instead of 'my_project' or 'my.project'"
        return 1
    fi

    log_info "Deployment name: $name (valid)"
    return 0
}

# -----------------------------------------------------------------------------
# Check required common variables
# -----------------------------------------------------------------------------
check_common_vars() {
    if [ -z "$OWNER" ]; then
        log_error "OWNER variable is not set. Please set it in .env file."
        return 1
    fi
    log_info "Owner: $OWNER"

    # Validate DEPLOYMENT_NAME format for Redis Enterprise compatibility
    if [ -n "$DEPLOYMENT_NAME" ]; then
        if ! validate_deployment_name "$DEPLOYMENT_NAME"; then
            return 1
        fi
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Check SSH public key file exists
# -----------------------------------------------------------------------------
check_ssh_key() {
    if [ -n "$SSH_PUBLIC_KEY" ]; then
        # Expand tilde if present
        local expanded_key="${SSH_PUBLIC_KEY/#\~/$HOME}"
        if [ ! -f "$expanded_key" ]; then
            log_error "SSH public key file not found: $SSH_PUBLIC_KEY"
            echo "Please check SSH_PUBLIC_KEY in your .env file."
            return 1
        fi
        log_info "SSH public key: $SSH_PUBLIC_KEY"
    fi
    return 0
}

# -----------------------------------------------------------------------------
# Build Redis Enterprise URL from components
# -----------------------------------------------------------------------------
build_redis_url() {
    local project_root="${1:-$PROJECT_ROOT}"
    
    # If URL is already set, use it
    if [ -n "$REDIS_ENTERPRISE_URL" ]; then
        log_info "Using Redis URL: $REDIS_ENTERPRISE_URL"
        return 0
    fi
    
    # Check required base URL
    if [ -z "$REDIS_DOWNLOAD_BASE_URL" ]; then
        log_error "REDIS_DOWNLOAD_BASE_URL variable is not set."
        return 1
    fi
    
    # Check required OS and architecture
    if [ -z "$REDIS_OS" ]; then
        log_error "REDIS_OS variable is not set."
        return 1
    fi
    if [ -z "$REDIS_ARCHITECTURE" ]; then
        log_error "REDIS_ARCHITECTURE variable is not set."
        return 1
    fi
    
    # Auto-detect version if not set
    if [ -z "$REDIS_VERSION" ] || [ -z "$REDIS_BUILD" ]; then
        local version_script="$project_root/scripts/get_latest_redis_version.sh"
        if [ -f "$version_script" ]; then
            echo "Auto-detecting Redis Enterprise version..."
            # shellcheck source=/dev/null
            source "$version_script" > /dev/null 2>&1
            if [ -z "$REDIS_VERSION" ] || [ -z "$REDIS_BUILD" ]; then
                log_error "Failed to auto-detect Redis version"
                return 1
            fi
            log_info "Detected version: $REDIS_VERSION-$REDIS_BUILD"
        else
            log_error "Version detection script not found and REDIS_VERSION/REDIS_BUILD not set"
            return 1
        fi
    fi
    
    # Construct the full URL
    REDIS_ENTERPRISE_URL="${REDIS_DOWNLOAD_BASE_URL}/${REDIS_VERSION}/redislabs-${REDIS_VERSION}-${REDIS_BUILD}-${REDIS_OS}-${REDIS_ARCHITECTURE}.tar"
    export REDIS_ENTERPRISE_URL
    log_info "Constructed Redis URL: $REDIS_ENTERPRISE_URL"
    return 0
}

# -----------------------------------------------------------------------------
# Build common Terraform variables
# -----------------------------------------------------------------------------
build_common_vars() {
    VAR_ARGS=""

    # Add common tags
    VAR_ARGS="$VAR_ARGS -var=\"owner=$OWNER\""
    VAR_ARGS="$VAR_ARGS -var=\"skip_deletion=${SKIP_DELETION:-yes}\""

    # Add Redis Enterprise URL
    VAR_ARGS="$VAR_ARGS -var=\"rs_release=$REDIS_ENTERPRISE_URL\""

    # Add deployment name if set
    if [ -n "$DEPLOYMENT_NAME" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"deployment_name=$DEPLOYMENT_NAME\""
    fi

    # Add common cluster configuration
    if [ -n "$SSH_PUBLIC_KEY" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"ssh_public_key=$SSH_PUBLIC_KEY\""
    fi
    if [ -n "$CLUSTER_SIZE" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"cluster_size=$CLUSTER_SIZE\""
    fi
    if [ -n "$ROOT_VOLUME_SIZE" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"volume_size=$ROOT_VOLUME_SIZE\""
    fi

    # Add flash/storage configuration
    if [ -n "$FLASH_ENABLED" ]; then
        VAR_ARGS="$VAR_ARGS -var=\"flash_enabled=$FLASH_ENABLED\""
    fi

    export VAR_ARGS
}

# -----------------------------------------------------------------------------
# Print deployment summary
# -----------------------------------------------------------------------------
print_summary() {
    local cloud_provider="$1"

    log_header "Applying Terraform/OpenTofu configuration"
    echo "Cloud Provider: $cloud_provider"
    echo "Deployment: ${DEPLOYMENT_NAME:-<not set>}"
    echo "Owner: $OWNER"
    echo "Skip Deletion: ${SKIP_DELETION:-yes}"
    echo "Redis Enterprise: $REDIS_ENTERPRISE_URL"
    echo "========================================="
    echo ""
}

# -----------------------------------------------------------------------------
# Execute tofu apply
# -----------------------------------------------------------------------------
run_tofu_apply() {
    local auto_approve_flag=""
    if [ "$AUTO_APPROVE" = "yes" ]; then
        auto_approve_flag="-auto-approve"
    fi

    eval "tofu apply $VAR_ARGS $auto_approve_flag"
}

# -----------------------------------------------------------------------------
# Execute tofu destroy
# -----------------------------------------------------------------------------
run_tofu_destroy() {
    local auto_approve_flag=""
    if [ "$AUTO_APPROVE" = "yes" ]; then
        auto_approve_flag="-auto-approve"
    fi

    eval "tofu destroy $VAR_ARGS $auto_approve_flag"
}

# -----------------------------------------------------------------------------
# Execute tofu plan
# -----------------------------------------------------------------------------
run_tofu_plan() {
    eval "tofu plan $VAR_ARGS"
}

