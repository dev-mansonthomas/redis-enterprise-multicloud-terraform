# Scripts Directory

Utility scripts for managing Redis Enterprise deployments across multiple cloud providers.

## Utility Scripts

| Script | Description |
|--------|-------------|
| `verify_setup.sh` | Validate environment configuration and CLI tools |
| `get_latest_redis_version.sh` | Fetch latest Redis Enterprise version |
| `aws_quota_check.sh` | List AWS vCPU quotas by region |
| `gcp_quota_check.sh` | List GCP CPU quotas by region |
| `azure_quota_check.sh` | List Azure vCPU quotas by region |
| `toggle_sensitive.sh` | Hide/show sensitive values in terraform output |

## Template Scripts

| Script | Description |
|--------|-------------|
| `tofu_apply_template.sh` | Template for applying Terraform configurations |
| `tofu_destroy_template.sh` | Template for destroying Terraform configurations |

## Usage

### Verify Setup

Check that your environment is properly configured:

```bash
./scripts/verify_setup.sh
```

### Check Quotas

Before deploying, verify you have sufficient quota:

```bash
# AWS
./scripts/aws_quota_check.sh us-east-1

# GCP
./scripts/gcp_quota_check.sh us-central1

# Azure
./scripts/azure_quota_check.sh westeurope
```

### Get Redis Version

Check the latest Redis Enterprise version:

```bash
./scripts/get_latest_redis_version.sh
```

## See Also

- [README](../README_new.md) - Main project documentation

