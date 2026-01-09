#!/bin/bash
# =============================================================================
# OpenTofu/Terraform apply script
# This script is called from the configuration directory after pre-flight checks
# =============================================================================

# Determine the project root directory (go up from current config directory)
# Find project root by looking for .env file
find_project_root() {
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/.env" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

PROJECT_ROOT="$(find_project_root)"
if [ -z "$PROJECT_ROOT" ]; then
    echo "Error: Could not find project root (no .env file found)"
    exit 1
fi

# Source common functions and provider scripts
source "$PROJECT_ROOT/scripts/common.sh"

# Load environment
load_env "$PROJECT_ROOT" || exit 1

# Determine cloud provider from current directory
CURRENT_DIR=$(pwd)
if [[ "$CURRENT_DIR" == *"/AWS/"* ]]; then
    CLOUD_PROVIDER="aws"
    source "$PROJECT_ROOT/scripts/providers/aws.sh"
elif [[ "$CURRENT_DIR" == *"/GCP/"* ]]; then
    CLOUD_PROVIDER="gcp"
    source "$PROJECT_ROOT/scripts/providers/gcp.sh"
elif [[ "$CURRENT_DIR" == *"/Azure/"* ]]; then
    CLOUD_PROVIDER="azure"
    source "$PROJECT_ROOT/scripts/providers/azure.sh"
else
    log_error "Cannot determine cloud provider from current directory"
    exit 1
fi

# Build Redis URL
build_redis_url "$PROJECT_ROOT" || exit 1

# Build common variables
build_common_vars

# Build provider-specific variables
case $CLOUD_PROVIDER in
    aws)   build_aws_vars || exit 1 ;;
    gcp)   build_gcp_vars || exit 1 ;;
    azure) build_azure_vars || exit 1 ;;
esac

# Print summary and run
print_summary "$CLOUD_PROVIDER"
run_tofu_apply
