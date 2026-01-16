#!/bin/bash

# Generic OpenTofu/Terraform apply script
# This script loads credentials and tags from .env file and applies the configuration

# Determine the project root directory
# This script is located at: main/Azure/Mono-Region/Rack_Aware_Cluster/tofu_apply.sh
# So we need to go up 4 levels to reach the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Load environment variables from .env file at project root
ENV_FILE="$PROJECT_ROOT/.env"
if [ -f "$ENV_FILE" ]; then
    echo "Loading configuration from $ENV_FILE..."
    source "$ENV_FILE"
else
    echo "Error: .env file not found at project root: $ENV_FILE"
    echo "Please create a .env file at the project root with your configuration."
    exit 1
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

# ===========================================
# Verify required files exist before running
# ===========================================
echo "Verifying required files..."

# Check SSH public key file
if [ -n "$SSH_PUBLIC_KEY" ]; then
    if [ ! -f "$SSH_PUBLIC_KEY" ]; then
        echo "Error: SSH public key file not found: $SSH_PUBLIC_KEY"
        echo "Please check SSH_PUBLIC_KEY in your .env file."
        exit 1
    fi
    echo "  ✓ SSH public key: $SSH_PUBLIC_KEY"
fi

# Check cloud-specific credential files
case $CLOUD_PROVIDER in
    aws)
        # Check AWS credentials file
        if [ -n "$AWS_CREDENTIALS_FILE" ]; then
            if [ ! -f "$AWS_CREDENTIALS_FILE" ]; then
                echo "Error: AWS credentials file not found: $AWS_CREDENTIALS_FILE"
                echo "Please check AWS_CREDENTIALS_FILE in your .env file."
                exit 1
            fi
            echo "  ✓ AWS credentials: $AWS_CREDENTIALS_FILE"
        elif [ -f ~/.cred/aws.sh ]; then
            echo "  ✓ AWS credentials: ~/.cred/aws.sh (default)"
        else
            echo "Warning: No AWS credentials file found. Will use environment variables or AWS CLI profile."
        fi
        ;;
    gcp)
        # Check GCP credentials file
        if [ -z "$GCP_CREDENTIALS_FILE" ]; then
            echo "Error: GCP_CREDENTIALS_FILE is not set in .env file."
            exit 1
        fi
        if [ ! -f "$GCP_CREDENTIALS_FILE" ]; then
            echo "Error: GCP credentials file not found: $GCP_CREDENTIALS_FILE"
            echo "Please check GCP_CREDENTIALS_FILE in your .env file."
            exit 1
        fi
        echo "  ✓ GCP credentials: $GCP_CREDENTIALS_FILE"
        ;;
    azure)
        # Azure uses environment variables or az login, no file check needed
        if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
            echo "Warning: AZURE_SUBSCRIPTION_ID is not set. Make sure you're logged in with 'az login'."
        else
            echo "  ✓ Azure subscription ID configured"
        fi
        ;;
esac

echo "File verification complete."
echo ""

# Auto-construct REDIS_ENTERPRISE_URL if not set
if [ -z "$REDIS_ENTERPRISE_URL" ]; then
    # Check required base URL
    if [ -z "$REDIS_DOWNLOAD_BASE_URL" ]; then
        echo "Error: REDIS_DOWNLOAD_BASE_URL variable is not set. Please set it in .env file."
        exit 1
    fi

    # Check required OS and architecture
    if [ -z "$REDIS_OS" ]; then
        echo "Error: REDIS_OS variable is not set. Please set it in .env file."
        exit 1
    fi
    if [ -z "$REDIS_ARCHITECTURE" ]; then
        echo "Error: REDIS_ARCHITECTURE variable is not set. Please set it in .env file."
        exit 1
    fi

    # Auto-detect version if not set
    if [ -z "$REDIS_VERSION" ] || [ -z "$REDIS_BUILD" ]; then
        VERSION_SCRIPT="$PROJECT_ROOT/scripts/get_latest_redis_version.sh"
        if [ -f "$VERSION_SCRIPT" ]; then
            echo "Auto-detecting Redis Enterprise version..."
            source "$VERSION_SCRIPT" > /dev/null 2>&1
            if [ -z "$REDIS_VERSION" ] || [ -z "$REDIS_BUILD" ]; then
                echo "Error: Failed to auto-detect Redis version"
                exit 1
            fi
            echo "Detected version: $REDIS_VERSION-$REDIS_BUILD"
        else
            echo "Error: Version detection script not found and REDIS_VERSION/REDIS_BUILD not set"
            exit 1
        fi
    fi

    # Construct the full URL
    REDIS_ENTERPRISE_URL="${REDIS_DOWNLOAD_BASE_URL}/${REDIS_VERSION}/redislabs-${REDIS_VERSION}-${REDIS_BUILD}-${REDIS_OS}-${REDIS_ARCHITECTURE}.tar"
    echo "Constructed Redis URL: $REDIS_ENTERPRISE_URL"
fi

# Build variable arguments based on cloud provider
VAR_ARGS=""

# Add common tags
VAR_ARGS="$VAR_ARGS -var=\"owner=$OWNER\""
VAR_ARGS="$VAR_ARGS -var=\"skip_deletion=${SKIP_DELETION:-yes}\""

# Add Redis Enterprise URL
VAR_ARGS="$VAR_ARGS -var=\"rs_release=$REDIS_ENTERPRISE_URL\""

# Add Redis Enterprise admin credentials (required)
if [ -z "$REDIS_LOGIN" ] || [ -z "$REDIS_PWD" ]; then
    echo "Error: REDIS_LOGIN and REDIS_PWD must be set in .env file."
    exit 1
fi
VAR_ARGS="$VAR_ARGS -var=\"rs_user=$REDIS_LOGIN\""
VAR_ARGS="$VAR_ARGS -var=\"rs_password=$REDIS_PWD\""

# Add deployment name if set
if [ -n "$DEPLOYMENT_NAME" ]; then
    VAR_ARGS="$VAR_ARGS -var=\"deployment_name=$DEPLOYMENT_NAME\""
fi

# Add common cluster configuration
if [ -n "$SSH_PUBLIC_KEY" ]; then
    VAR_ARGS="$VAR_ARGS -var=\"ssh_public_key=$SSH_PUBLIC_KEY\""
fi
if [ -n "$SSH_PRIVATE_KEY" ]; then
    VAR_ARGS="$VAR_ARGS -var=\"ssh_private_key=$SSH_PRIVATE_KEY\""
fi
if [ -n "$CLUSTER_SIZE" ]; then
    VAR_ARGS="$VAR_ARGS -var=\"cluster_size=$CLUSTER_SIZE\""
fi
if [ -n "$ROOT_VOLUME_SIZE" ]; then
    VAR_ARGS="$VAR_ARGS -var=\"volume_size=$ROOT_VOLUME_SIZE\""
fi
if [ -n "$FLASH_ENABLED" ]; then
    VAR_ARGS="$VAR_ARGS -var=\"flash_enabled=$FLASH_ENABLED\""
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
        if [ -n "$AWS_MACHINE_IMAGE" ]; then
            VAR_ARGS="$VAR_ARGS -var=\"machine_image=$AWS_MACHINE_IMAGE\""
        fi
        if [ -n "$AWS_HOSTED_ZONE" ]; then
            VAR_ARGS="$VAR_ARGS -var=\"hosted_zone=$AWS_HOSTED_ZONE\""
        fi
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

        # Add GCP-specific configuration
        if [ -n "$GCP_REGION_NAME" ]; then
            VAR_ARGS="$VAR_ARGS -var=\"region_name=$GCP_REGION_NAME\""
        fi
        if [ -n "$GCP_MACHINE_TYPE" ]; then
            VAR_ARGS="$VAR_ARGS -var=\"machine_type=$GCP_MACHINE_TYPE\""
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
        ;;

    azure)
        # Load Azure credentials
        if [ -n "$AZURE_CREDENTIALS_FILE" ]; then
            # Expand tilde in path
            AZURE_CREDENTIALS_FILE="${AZURE_CREDENTIALS_FILE/#\~/$HOME}"
            if [ -f "$AZURE_CREDENTIALS_FILE" ]; then
                echo "Loading Azure credentials from $AZURE_CREDENTIALS_FILE..."
                source "$AZURE_CREDENTIALS_FILE"
            else
                echo "Warning: Azure credentials file not found: $AZURE_CREDENTIALS_FILE"
            fi
        elif [ -f ~/.cred/azure.sh ]; then
            echo "Loading Azure credentials from ~/.cred/azure.sh..."
            source ~/.cred/azure.sh
        fi

        # Azure requires at minimum subscription_id
        if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
            echo "Error: AZURE_SUBSCRIPTION_ID is not set in .env file or credentials file."
            exit 1
        fi

        VAR_ARGS="$VAR_ARGS -var=\"azure_subscription_id=$AZURE_SUBSCRIPTION_ID\""

        # Check authentication mode: Service Principal or Azure CLI
        if [ -n "$AZURE_CLIENT_ID" ] && [ -n "$AZURE_CLIENT_SECRET" ] && [ -n "$AZURE_TENANT_ID" ]; then
            # Service Principal authentication
            echo "Using Service Principal authentication"
            VAR_ARGS="$VAR_ARGS -var=\"azure_tenant_id=$AZURE_TENANT_ID\""
            VAR_ARGS="$VAR_ARGS -var=\"azure_access_key_id=$AZURE_CLIENT_ID\""
            VAR_ARGS="$VAR_ARGS -var=\"azure_secret_key=$AZURE_CLIENT_SECRET\""
            VAR_ARGS="$VAR_ARGS -var=\"use_cli_auth=false\""
        else
            # Azure CLI authentication - verify az login
            echo "Using Azure CLI authentication (az login)"
            if ! az account show &>/dev/null; then
                echo "Error: Not logged in to Azure CLI. Please run 'az login' first."
                exit 1
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

        # Azure-specific SSH keys (RSA only - Azure doesn't support ed25519)
        if [ -n "$AZURE_SSH_PUBLIC_KEY" ]; then
            # Expand tilde
            AZURE_SSH_PUBLIC_KEY="${AZURE_SSH_PUBLIC_KEY/#\~/$HOME}"
            if [ -f "$AZURE_SSH_PUBLIC_KEY" ]; then
                echo "Using Azure-specific RSA SSH public key: $AZURE_SSH_PUBLIC_KEY"
                VAR_ARGS="$VAR_ARGS -var=\"ssh_public_key=$AZURE_SSH_PUBLIC_KEY\""
            else
                echo "Error: Azure SSH public key file not found: $AZURE_SSH_PUBLIC_KEY"
                exit 1
            fi
        fi
        if [ -n "$AZURE_SSH_PRIVATE_KEY" ]; then
            # Expand tilde
            AZURE_SSH_PRIVATE_KEY="${AZURE_SSH_PRIVATE_KEY/#\~/$HOME}"
            if [ -f "$AZURE_SSH_PRIVATE_KEY" ]; then
                echo "Using Azure-specific RSA SSH private key: $AZURE_SSH_PRIVATE_KEY"
                VAR_ARGS="$VAR_ARGS -var=\"ssh_private_key=$AZURE_SSH_PRIVATE_KEY\""
            else
                echo "Error: Azure SSH private key file not found: $AZURE_SSH_PRIVATE_KEY"
                exit 1
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
        if [ -n "$AZ_DNS_RESOURCE_GROUP" ]; then
            VAR_ARGS="$VAR_ARGS -var=\"dns_resource_group=$AZ_DNS_RESOURCE_GROUP\""
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
echo "Applying Terraform/OpenTofu configuration"
echo "========================================="
echo "Cloud Provider: $CLOUD_PROVIDER"
echo "Deployment: ${DEPLOYMENT_NAME:-<not set>}"
echo "Owner: $OWNER"
echo "Skip Deletion: ${SKIP_DELETION:-yes}"
echo "Redis Enterprise: $REDIS_ENTERPRISE_URL"
echo "Flash Enabled: ${FLASH_ENABLED:-false}"
echo "========================================="
echo ""

# Setup logging
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/apply_$(date +%Y%m%d_%H%M%S).log"
echo "Full log will be saved to: $LOG_FILE"
echo ""

# Execute tofu apply with all variables
eval "tofu apply $VAR_ARGS $AUTO_APPROVE_FLAG" 2>&1 | tee "$LOG_FILE" | grep -v -E '(^module\.[^(]+\(remote-exec\):.*%(\ \[|Working|Waiting|Get:|Fetched|Reading)|\(remote-exec\):.*kB/|^\s*$)' | grep -v -E '^\s+[0-9]+%'

# Show completion message
echo ""
echo "========================================="
echo "Log file saved to: $LOG_FILE"
echo "========================================="

