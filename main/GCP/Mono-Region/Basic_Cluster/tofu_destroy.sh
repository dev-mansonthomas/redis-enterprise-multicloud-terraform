#!/bin/bash

# Generic OpenTofu/Terraform destroy script
# This script loads credentials and tags from .env file and destroys the configuration

# Determine the project root directory
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

# Auto-construct REDIS_ENTERPRISE_URL if not set
if [ -z "$REDIS_ENTERPRISE_URL" ]; then
    if [ -z "$REDIS_DOWNLOAD_BASE_URL" ]; then
        echo "Error: REDIS_DOWNLOAD_BASE_URL variable is not set. Please set it in .env file."
        exit 1
    fi
    if [ -z "$REDIS_OS" ]; then
        echo "Error: REDIS_OS variable is not set. Please set it in .env file."
        exit 1
    fi
    if [ -z "$REDIS_ARCHITECTURE" ]; then
        echo "Error: REDIS_ARCHITECTURE variable is not set. Please set it in .env file."
        exit 1
    fi
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
if [ -n "$CLUSTER_SIZE" ]; then
    VAR_ARGS="$VAR_ARGS -var=\"cluster_size=$CLUSTER_SIZE\""
fi
if [ -n "$ROOT_VOLUME_SIZE" ]; then
    VAR_ARGS="$VAR_ARGS -var=\"volume_size=$ROOT_VOLUME_SIZE\""
fi
if [ -n "$FLASH_ENABLED" ]; then
    VAR_ARGS="$VAR_ARGS -var=\"flash_enabled=$FLASH_ENABLED\""
fi

# Add bastion tools variables (required for state consistency)
REDIS_CLI_VER="${REDIS_CLI_VERSION:-8.4.0}"
MEMTIER_VER="${MEMTIER_VERSION:-2.2.1}"
MEMTIER_PACKAGE="https://github.com/RedisLabs/memtier_benchmark/archive/refs/tags/${MEMTIER_VER}.tar.gz"
PROM_VER="${PROMETHEUS_VERSION:-3.9.1}"
PROMETHEUS_PACKAGE="https://github.com/prometheus/prometheus/releases/download/v${PROM_VER}/prometheus-${PROM_VER}.linux-amd64.tar.gz"
GRAFANA_VER="${GRAFANA_VERSION:-12.3.1}"
JAVA_VER="${JAVA_VERSION:-21}"

VAR_ARGS="$VAR_ARGS -var=\"memtier_package=$MEMTIER_PACKAGE\""
VAR_ARGS="$VAR_ARGS -var=\"prometheus_package=$PROMETHEUS_PACKAGE\""
VAR_ARGS="$VAR_ARGS -var=\"grafana_version=$GRAFANA_VER\""
VAR_ARGS="$VAR_ARGS -var=\"java_version=$JAVA_VER\""
VAR_ARGS="$VAR_ARGS -var=\"redis_cli_version=$REDIS_CLI_VER\""

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
        if [ -n "$AZ_MACHINE_IMAGE" ]; then
            VAR_ARGS="$VAR_ARGS -var=\"machine_image=$AZ_MACHINE_IMAGE\""
        fi
        if [ -n "$AZ_HOSTED_ZONE" ]; then
            VAR_ARGS="$VAR_ARGS -var=\"hosted_zone=$AZ_HOSTED_ZONE\""
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

