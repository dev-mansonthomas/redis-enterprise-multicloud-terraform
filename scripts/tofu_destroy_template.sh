#!/bin/bash

# Generic OpenTofu/Terraform destroy script
# This script loads credentials and tags from .env file and destroys the configuration

# Determine the path to .env file (search up to 3 levels)
ENV_FILE=""
for level in "" "../" "../../" "../../../"; do
    if [ -f "${level}.env" ]; then
        ENV_FILE="${level}.env"
        break
    fi
done

# Load environment variables from .env file
if [ -n "$ENV_FILE" ]; then
    echo "Loading configuration from $ENV_FILE..."
    source "$ENV_FILE"
else
    echo "Warning: .env file not found. Using default credentials."
fi

# Determine cloud provider from current directory
CURRENT_DIR=$(pwd)
if [[ "$CURRENT_DIR" == *"/AWS/"* ]]; then
    CLOUD_PROVIDER="aws"
elif [[ "$CURRENT_DIR" == *"/GCP/"* ]]; then
    CLOUD_PROVIDER="gcp"
elif [[ "$CURRENT_DIR" == *"/Azure/"* ]]; then
    CLOUD_PROVIDER="azure"
else
    echo "Error: Cannot determine cloud provider from current directory"
    exit 1
fi

# Check if required variables are set
if [ -z "$OWNER" ]; then
    echo "Error: OWNER variable is not set. Please set it in .env file."
    exit 1
fi

# Auto-detect Redis version if not set
if [ -z "$REDIS_VERSION" ] || [ -z "$REDIS_BUILD" ]; then
    echo "Redis version not set, auto-detecting latest version..."

    # Find the script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    VERSION_SCRIPT="$SCRIPT_DIR/get_latest_redis_version.sh"

    if [ -f "$VERSION_SCRIPT" ]; then
        # Source the script to get the version variables
        source "$VERSION_SCRIPT" > /dev/null

        if [ -z "$REDIS_VERSION" ] || [ -z "$REDIS_BUILD" ]; then
            echo "Error: Failed to auto-detect Redis version"
            exit 1
        fi

        echo "Auto-detected Redis version: $REDIS_VERSION-$REDIS_BUILD"
    else
        echo "Error: Version detection script not found at $VERSION_SCRIPT"
        echo "Please set REDIS_VERSION and REDIS_BUILD in .env file."
        exit 1
    fi
fi

# Check OS and architecture
if [ -z "$REDIS_OS" ]; then
    echo "Error: REDIS_OS variable is not set. Please set it in .env file."
    echo "Supported values: jammy, focal, rhel8, rhel9"
    exit 1
fi

if [ -z "$REDIS_ARCHITECTURE" ]; then
    echo "Error: REDIS_ARCHITECTURE variable is not set. Please set it in .env file."
    echo "Supported values: amd64, arm64"
    exit 1
fi

# Check Redis download base URL
if [ -z "$REDIS_DOWNLOAD_BASE_URL" ]; then
    echo "Error: REDIS_DOWNLOAD_BASE_URL variable is not set. Please set it in .env file."
    echo "Example: REDIS_DOWNLOAD_BASE_URL=https://your-private-mirror.com/redis-enterprise"
    exit 1
fi

# Construct Redis Enterprise URL if not explicitly set
if [ -z "$REDIS_ENTERPRISE_URL" ]; then
    REDIS_ENTERPRISE_URL="${REDIS_DOWNLOAD_BASE_URL}/${REDIS_VERSION}/redislabs-${REDIS_VERSION}-${REDIS_BUILD}-${REDIS_OS}-${REDIS_ARCHITECTURE}.tar"
    echo "Constructed Redis Enterprise URL: $REDIS_ENTERPRISE_URL"
fi

# Build variable arguments based on cloud provider
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

# Add cloud-specific credentials
case $CLOUD_PROVIDER in
    aws)
        # Load AWS credentials
        if [ -n "$AWS_CREDENTIALS_FILE" ] && [ -f "$AWS_CREDENTIALS_FILE" ]; then
            echo "Loading AWS credentials from $AWS_CREDENTIALS_FILE..."
            source "$AWS_CREDENTIALS_FILE"
        elif [ -f ~/.cred/aws.sh ]; then
            echo "Loading AWS credentials from ~/.cred/aws.sh..."
            source ~/.cred/aws.sh
        fi
        
        AWS_KEY="${AWS_ACCESS_KEY:-$KEY}"
        AWS_SEC="${AWS_SECRET_KEY:-$SEC}"
        
        if [ -z "$AWS_KEY" ] || [ -z "$AWS_SEC" ]; then
            echo "Error: AWS credentials are not set."
            exit 1
        fi
        
        VAR_ARGS="$VAR_ARGS -var=\"aws_access_key=$AWS_KEY\""
        VAR_ARGS="$VAR_ARGS -var=\"aws_secret_key=$AWS_SEC\""
        ;;
        
    gcp)
        if [ -z "$GCP_CREDENTIALS_FILE" ]; then
            echo "Error: GCP_CREDENTIALS_FILE is not set in .env file."
            exit 1
        fi
        
        if [ ! -f "$GCP_CREDENTIALS_FILE" ]; then
            echo "Error: GCP credentials file not found: $GCP_CREDENTIALS_FILE"
            exit 1
        fi
        
        VAR_ARGS="$VAR_ARGS -var=\"credentials=$GCP_CREDENTIALS_FILE\""
        
        if [ -n "$GCP_PROJECT_ID" ]; then
            VAR_ARGS="$VAR_ARGS -var=\"project=$GCP_PROJECT_ID\""
        fi
        ;;
        
    azure)
        if [ -z "$AZURE_SUBSCRIPTION_ID" ] || [ -z "$AZURE_TENANT_ID" ]; then
            echo "Error: Azure credentials are not set in .env file."
            exit 1
        fi
        
        VAR_ARGS="$VAR_ARGS -var=\"subscription_id=$AZURE_SUBSCRIPTION_ID\""
        VAR_ARGS="$VAR_ARGS -var=\"tenant_id=$AZURE_TENANT_ID\""
        
        if [ -n "$AZURE_CLIENT_ID" ]; then
            VAR_ARGS="$VAR_ARGS -var=\"client_id=$AZURE_CLIENT_ID\""
        fi
        
        if [ -n "$AZURE_CLIENT_SECRET" ]; then
            VAR_ARGS="$VAR_ARGS -var=\"client_secret=$AZURE_CLIENT_SECRET\""
        fi
        ;;
esac

# Set auto-approve flag
AUTO_APPROVE_FLAG=""
if [ "$AUTO_APPROVE" = "yes" ]; then
    AUTO_APPROVE_FLAG="-auto-approve"
fi

echo ""
echo "========================================="
echo "Destroying Terraform/OpenTofu configuration"
echo "========================================="
echo "Cloud Provider: $CLOUD_PROVIDER"
echo "Deployment: ${DEPLOYMENT_NAME:-<not set>}"
echo "Owner: $OWNER"
echo "Redis Enterprise: $REDIS_ENTERPRISE_URL"
echo "========================================="
echo ""

# Execute tofu destroy with all variables
eval "tofu destroy $VAR_ARGS $AUTO_APPROVE_FLAG"

