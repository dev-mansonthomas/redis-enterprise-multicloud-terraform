# Tagging and Credentials Management

This document explains how to configure and use the tagging and credentials management system for this Terraform/OpenTofu project.

## Overview

All cloud resources created by this project are automatically tagged with:
- **owner**: Your name in the format `firstname_lastname` (e.g., `steve_jenner`)
- **skip_deletion**: Set to `yes` for resources that should not be deleted

Cloud provider credentials are managed through a `.env` file that is excluded from version control.

## Setup

### 1. Create your `.env` file

Copy the sample environment file:

```bash
cp .env.sample .env
```

### 2. Configure your `.env` file

Edit the `.env` file and set the required variables:

#### Required for all deployments:

```bash
# Owner tag (required)
OWNER=firstname_lastname

# Skip deletion tag (optional, defaults to "yes")
SKIP_DELETION=yes

# Redis Enterprise download URL (required)
# Get the latest version from: https://redis.io/downloads/
REDIS_ENTERPRISE_URL=https://s3.amazonaws.com/redis-enterprise-software-downloads/8.0.6/redislabs-8.0.6-54-jammy-amd64.tar

# Deployment name (optional, can be overridden per deployment)
DEPLOYMENT_NAME=my-deployment

# Auto-approve (optional, set to "yes" to skip confirmation prompts)
AUTO_APPROVE=no
```

#### AWS Credentials:

Choose one of the following methods:

**Option 1: Use a credentials file**
```bash
AWS_CREDENTIALS_FILE=/path/to/your/aws/credentials.sh
```

The credentials file should export `KEY` and `SEC` variables:
```bash
export KEY="your-aws-access-key"
export SEC="your-aws-secret-key"
```

**Option 2: Set credentials directly in .env**
```bash
AWS_ACCESS_KEY=your-aws-access-key
AWS_SECRET_KEY=your-aws-secret-key
```

#### GCP Credentials:

```bash
GCP_CREDENTIALS_FILE=/path/to/your/gcp/credentials.json
GCP_PROJECT_ID=your-gcp-project-id
```

#### Azure Credentials:

```bash
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_TENANT_ID=your-tenant-id
AZURE_CLIENT_ID=your-client-id
AZURE_CLIENT_SECRET=your-client-secret
```

### 3. Protect your `.env` file

The `.env` file is already added to `.gitignore` and will not be committed to version control.

**Important**: Never commit credentials to version control!

## Usage

### Deploying Infrastructure

Navigate to any configuration directory and run:

```bash
./tofu_apply.sh
```

The script will:
1. Automatically detect the cloud provider (AWS, GCP, or Azure)
2. Load credentials from your `.env` file
3. Apply the configuration with the appropriate tags

### Destroying Infrastructure

Navigate to any configuration directory and run:

```bash
./tofu_destroy.sh
```

### Example Workflow

```bash
# 1. Configure your environment
cp .env.sample .env
vim .env  # Edit with your credentials and owner tag

# 2. Deploy an AWS cluster
cd main/AWS/Mono-Region/Rack_Aware_Cluster
./tofu_apply.sh

# 3. Destroy the cluster when done
./tofu_destroy.sh
```

## How It Works

### Tagging

All resources are tagged using a `locals` block in each configuration:

```json
"locals": {
    "common_tags": {
        "owner": "${var.owner}",
        "skip_deletion": "${var.skip_deletion}"
    }
}
```

These tags are then passed to all modules via the `resource_tags` parameter.

### Cloud Provider Differences

- **AWS**: Uses `tags` attribute
- **GCP**: Uses `labels` attribute
- **Azure**: Uses `tags` attribute

The modules handle these differences automatically.

### Scripts

Each configuration directory contains:
- `tofu_apply.sh`: Applies the configuration
- `tofu_destroy.sh`: Destroys the configuration

These scripts are generated from templates in `scripts/` directory and automatically:
- Detect the cloud provider
- Load the appropriate credentials
- Pass the owner and skip_deletion tags
- Handle auto-approve settings

## Troubleshooting

### "OWNER variable is not set"

Make sure you have created a `.env` file and set the `OWNER` variable.

### "AWS/GCP/Azure credentials are not set"

Check that you have configured the appropriate credentials in your `.env` file for the cloud provider you're using.

### Tags not appearing on resources

Verify that:
1. The `owner` and `skip_deletion` variables are defined in `variables.tf`
2. The configuration file (`.tf.json`) includes a `locals` block with `common_tags`
3. Modules are called with `resource_tags = "${local.common_tags}"`

## Security Best Practices

1. **Never commit `.env` file**: It's already in `.gitignore`
2. **Use least privilege**: Grant only necessary permissions to service accounts
3. **Rotate credentials regularly**: Update your `.env` file when credentials change
4. **Use separate credentials per environment**: Don't share production credentials
5. **Encrypt credentials at rest**: Consider using encrypted filesystems or secret managers

## Support

For issues or questions, please contact your team lead or infrastructure team.

