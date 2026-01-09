# Deployment Shortcuts

This document explains the quick deployment scripts available at the project root.

## Overview

Instead of navigating through multiple directories to deploy configurations, you can use the quick deployment scripts located at the project root. These scripts automatically navigate to the correct configuration directory and run the deployment.

## Interactive Menu

The easiest way to deploy is using the interactive menu:

```bash
./deploy.sh
```

This will display a menu with all 18 available configurations. Simply enter the number corresponding to your desired configuration.

## Quick Deploy Scripts

All scripts follow a consistent naming pattern: `{provider}_{region_type}_{cluster_type}.sh`

### AWS Scripts

| Script | Configuration | Description |
|--------|--------------|-------------|
| `aws_mono_region_basic.sh` | AWS Mono-Region Basic | Single availability zone |
| `aws_mono_region_rack_aware.sh` | AWS Mono-Region Rack-Aware | Multiple availability zones |
| `aws_cross_region_basic.sh` | AWS Cross-Region Basic | Multi-region, single AZ per region |
| `aws_cross_region_rack_aware.sh` | AWS Cross-Region Rack-Aware | Multi-region, multi-AZ |

### GCP Scripts

| Script | Configuration | Description |
|--------|--------------|-------------|
| `gcp_mono_region_basic.sh` | GCP Mono-Region Basic | Single zone |
| `gcp_mono_region_rack_aware.sh` | GCP Mono-Region Rack-Aware | Multiple zones |
| `gcp_cross_region_basic.sh` | GCP Cross-Region Basic | Multi-region, single zone per region |
| `gcp_cross_region_rack_aware.sh` | GCP Cross-Region Rack-Aware | Multi-region, multi-zone |

### GCP GKE Scripts (Kubernetes)

| Script | Configuration | Description |
|--------|--------------|-------------|
| `gcp_gke_mono_region_basic.sh` | GCP GKE Mono-Region Basic | Single zone on Kubernetes |
| `gcp_gke_mono_region_rack_aware.sh` | GCP GKE Mono-Region Rack-Aware | Multiple zones on Kubernetes |
| `gcp_gke_cross_region_basic.sh` | GCP GKE Cross-Region Basic | Multi-region on Kubernetes |
| `gcp_gke_cross_region_rack_aware.sh` | GCP GKE Cross-Region Rack-Aware | Multi-region, multi-zone on Kubernetes |

### Azure Scripts

| Script | Configuration | Description |
|--------|--------------|-------------|
| `azure_mono_region_basic.sh` | Azure Mono-Region Basic | Single availability zone |
| `azure_mono_region_rack_aware.sh` | Azure Mono-Region Rack-Aware | Multiple availability zones |
| `azure_cross_region_basic.sh` | Azure Cross-Region Basic | Multi-region, single AZ per region |
| `azure_cross_region_rack_aware.sh` | Azure Cross-Region Rack-Aware | Multi-region, multi-AZ |

### Azure ACRE Scripts (Managed Service)

| Script | Configuration | Description |
|--------|--------------|-------------|
| `azure_acre_enterprise.sh` | Azure ACRE Enterprise | Azure Cache for Redis Enterprise |
| `azure_acre_oss.sh` | Azure ACRE OSS | Azure Cache for Redis OSS |

## Usage Examples

### Example 1: Deploy AWS Rack-Aware Cluster

From the project root:

```bash
./aws_mono_region_rack_aware.sh
```

This is equivalent to:

```bash
cd main/AWS/Mono-Region/Rack_Aware_Cluster
./tofu_apply.sh
```

### Example 2: Deploy GCP GKE Cross-Region

From the project root:

```bash
./gcp_gke_cross_region_rack_aware.sh
```

### Example 3: Deploy Azure ACRE Enterprise

From the project root:

```bash
./azure_acre_enterprise.sh
```

## How It Works

Each script:
1. Displays the configuration name
2. Checks if the configuration directory exists
3. Navigates to the configuration directory
4. Runs the `tofu_apply.sh` script in that directory

The `tofu_apply.sh` script then:
- Loads credentials from `.env`
- Validates required variables
- Applies the Terraform/OpenTofu configuration
- Tags all resources with `owner` and `skip_deletion`

## Destroying Infrastructure

To destroy infrastructure, navigate to the configuration directory and run:

```bash
cd main/AWS/Mono-Region/Rack_Aware_Cluster
./tofu_destroy.sh
```

**Note**: There are no quick destroy scripts at the root level to prevent accidental destruction.

## Prerequisites

Before using these scripts, make sure:

1. ✅ You have created and configured your `.env` file
2. ✅ You have set the required variables (`OWNER`, `REDIS_ENTERPRISE_URL`, credentials)
3. ✅ You have run `./scripts/verify_setup.sh` to verify your setup

## Benefits

✅ **No navigation required** - Deploy from anywhere in the project
✅ **Consistent naming** - Easy to remember script names
✅ **Interactive menu** - Choose from a list if you forget the script name
✅ **Error checking** - Scripts validate that directories exist
✅ **Clear output** - Shows which configuration is being deployed

## See Also

- [README.md](../README.md) - Quick start guide and main documentation
- [TAGGING_AND_CREDENTIALS.md](TAGGING_AND_CREDENTIALS.md) - Credentials setup
- [SHORTCUTS_REFERENCE.md](SHORTCUTS_REFERENCE.md) - Quick reference for all shortcuts

