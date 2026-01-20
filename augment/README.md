# Augment Context - Technical Reference

This directory contains technical documentation for AI assistants (like Augment) to quickly understand the project architecture.

## Project Overview

**Redis Enterprise Multicloud Terraform** - Deploy Redis Enterprise clusters on AWS, GCP, and Azure with a single command.

```
./aws_multi_az.sh           # Deploy
./aws_multi_az.sh --destroy # Destroy
```

## Project Structure

```
.
├── .env                    # User configuration (from .env.sample)
├── *.sh                    # Deployment scripts (aws_*, gcp_*, azure_*)
├── scripts/
│   ├── common.sh           # Shared functions for all scripts
│   ├── providers/          # Cloud-specific setup (aws.sh, gcp.sh, azure.sh)
│   ├── tofu_apply_template.sh
│   ├── tofu_destroy_template.sh
│   ├── get_latest_redis_version.sh
│   └── verify_setup.sh
├── main/                   # Terraform configurations
│   ├── AWS/
│   │   ├── Mono-Region/    # Single AZ deployment
│   │   └── Cross-Region/   # Multi-region Active-Active
│   ├── GCP/
│   │   ├── Mono-Region/
│   │   └── Cross-Region/
│   └── Azure/
│       ├── Mono-Region/
│       └── Cross-Region/
└── modules/                # Reusable Terraform modules
    ├── aws/
    │   ├── bastion/        # Bastion host with tools
    │   ├── network/        # VPC, subnets, security groups
    │   ├── re/             # Redis Enterprise nodes
    │   ├── ns-public/      # Route53 DNS
    │   └── peering/        # VPC peering for cross-region
    ├── gcp/
    │   ├── bastion/
    │   ├── network/
    │   ├── re/
    │   ├── ns-public/
    │   └── peering/
    ├── azure/
    │   ├── bastion/
    │   ├── network/
    │   ├── re/
    │   ├── ns-public/
    │   └── peering/
    └── common/
        └── cluster_dns/    # DNS record creation
```

## Key Configuration Files

### `.env` (from `.env.sample`)

```bash
# Identity
OWNER=firstname_lastname

# Redis Enterprise
REDIS_DOWNLOAD_BASE_URL=https://s3.amazonaws.com/redis-enterprise-software-downloads
REDIS_OS=jammy                    # jammy, focal, rhel8, rhel9
REDIS_ARCHITECTURE=amd64          # amd64, arm64
REDIS_VERSION=                    # Auto-detected if empty
REDIS_BUILD=                      # Auto-detected if empty

# Cluster
CLUSTER_SIZE=3
DEPLOYMENT_NAME=my-cluster

# SSH Keys
SSH_PUBLIC_KEY=~/.ssh/id_ed25519.pub
SSH_PRIVATE_KEY=~/.ssh/id_ed25519
AZURE_SSH_PUBLIC_KEY=~/.ssh/id_rsa.pub    # Azure requires RSA
AZURE_SSH_PRIVATE_KEY=~/.ssh/id_rsa

# Credentials (paths to files)
AWS_CREDENTIALS_FILE=~/.private/aws.sh
GCP_CREDENTIALS_FILE=~/.private/gcp-sa.json
AZURE_CREDENTIALS_FILE=~/.private/azure.sh
```

### Terraform Configuration Pattern

Each deployment in `main/` follows this pattern:
- `*.tf.json` - Main configuration (modules, resources)
- `variables.tf` - Variable declarations
- `tofu_apply.sh` - Sources template and runs apply
- `tofu_destroy.sh` - Sources template and runs destroy

## Script Flow

```
./aws_multi_az.sh
    │
    ├── source scripts/common.sh      # load_env(), log functions
    ├── source scripts/providers/aws.sh
    │
    ├── load_env()                    # Load .env file
    │
    ├── Auto-detect Redis version (if not set)
    │   └── scripts/get_latest_redis_version.sh
    │       └── Scrapes redis.io for latest version
    │
    ├── Construct REDIS_ENTERPRISE_URL
    │   └── ${BASE_URL}/${VERSION}/redislabs-${VERSION}-${BUILD}-${OS}-${ARCH}.tar
    │
    ├── Setup cloud credentials
    │   └── source $AWS_CREDENTIALS_FILE
    │
    └── cd main/AWS/Mono-Region/Rack_Aware_Cluster
        └── tofu apply -var="rs_release=$REDIS_ENTERPRISE_URL" ...
```

## Tagging System

All resources are tagged with:
- `owner` - From `.env` OWNER variable
- `skip_deletion` - Prevents auto-cleanup (default: "yes")

Tags flow: `.env` → deployment script → Terraform variables → module resources

## Important Technical Details

### Azure SSH Key Limitation
Azure does NOT support ed25519 keys. Two separate SSH key variables exist:
- `SSH_PUBLIC_KEY` / `SSH_PRIVATE_KEY` - For AWS & GCP (ed25519 OK)
- `AZURE_SSH_PUBLIC_KEY` / `AZURE_SSH_PRIVATE_KEY` - For Azure (RSA required)

### Redis Version Auto-Detection
`scripts/get_latest_redis_version.sh` scrapes redis.io release notes to find the latest version. Falls back to manual specification in `.env`.

### DNS Configuration
Each cloud provider has its own hosted zone:
- AWS: Route53 (`AWS_HOSTED_ZONE`)
- GCP: Cloud DNS (`GCP_DOMAIN_NAME`)
- Azure: Azure DNS (`AZ_HOSTED_ZONE` + `AZ_DNS_RESOURCE_GROUP`)

FQDN pattern: `<DEPLOYMENT_NAME>.<HOSTED_ZONE>`

## Architecture Documentation

See [ARCHITECTURE_REDIS_VERSION_AUTOMATION.md](ARCHITECTURE_REDIS_VERSION_AUTOMATION.md) for detailed version detection system architecture.

