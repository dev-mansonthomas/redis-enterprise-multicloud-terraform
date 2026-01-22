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

## Tag Verification Scripts

Scripts to verify that all cloud resources have proper `owner` and `skip_deletion` tags for cost tracking and cleanup automation.

| Script | Description |
|--------|-------------|
| `check_tags_aws.sh` | Verify AWS resource tags (EC2, VPC, EBS, etc.) |
| `check_tags_gcp.sh` | Verify GCP resource labels (instances, disks, IPs) |
| `check_tags_azure.sh` | Verify Azure resource tags (VMs, NICs, disks, etc.) |

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

### Verify Resource Tags

After deployment, verify all resources have proper tags for cost tracking:

```bash
# AWS - checks EC2 instances, volumes, VPCs, security groups, etc.
./scripts/check_tags_aws.sh

# GCP - checks compute instances, disks, static IPs
./scripts/check_tags_gcp.sh

# Azure - checks VMs, NICs, disks, public IPs, etc.
./scripts/check_tags_azure.sh
```

**Prerequisites:**
- Configure `OWNER` in your `.env` file
- Be logged into the respective cloud provider CLI (`aws`, `gcloud`, `az login`)

**What is checked:**

| Provider | Resources Checked | Tags Required |
|----------|-------------------|---------------|
| **AWS** | EC2 instances, EBS volumes, VPCs, subnets, security groups, NAT gateways, elastic IPs, VPC peering, key pairs | `owner`, `skip_deletion` |
| **GCP** | Compute instances, boot disks, static IP addresses | `owner`, `skip_deletion` |
| **Azure** | Resource groups, VMs, NICs, public IPs, storage accounts, managed disks, NSGs | `owner`, `skip_deletion` |

**Note:** Some resources don't support tags/labels:
- GCP: VPC networks, subnets, firewall rules, DNS records
- Azure: Subnets, VNet peerings
- AWS: Route53 records

## See Also

- [README](../README.md) - Main project documentation

