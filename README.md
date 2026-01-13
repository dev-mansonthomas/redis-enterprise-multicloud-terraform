# TerraMine

[![GitHub contributors](https://img.shields.io/github/contributors/dev-mansonthomas/redis-enterprise-multicloud-terraform)](https://github.com/dev-mansonthomas/redis-enterprise-multicloud-terraform/graphs/contributors)
[![Fork](https://img.shields.io/github/forks/dev-mansonthomas/redis-enterprise-multicloud-terraform)](https://github.com/dev-mansonthomas/redis-enterprise-multicloud-terraform/network/members)
[![GitHub Repo stars](https://img.shields.io/github/stars/dev-mansonthomas/redis-enterprise-multicloud-terraform)](https://github.com/dev-mansonthomas/redis-enterprise-multicloud-terraform/stargazers)
[![GitHub watchers](https://img.shields.io/github/watchers/dev-mansonthomas/redis-enterprise-multicloud-terraform)](https://github.com/dev-mansonthomas/redis-enterprise-multicloud-terraform/watchers)
[![GitHub issues](https://img.shields.io/github/issues/dev-mansonthomas/redis-enterprise-multicloud-terraform)](https://github.com/dev-mansonthomas/redis-enterprise-multicloud-terraform/issues)
[![License](https://img.shields.io/github/license/dev-mansonthomas/redis-enterprise-multicloud-terraform)](https://github.com/dev-mansonthomas/redis-enterprise-multicloud-terraform/blob/main/LICENSE)

---

TerraMine is a set of Terraform/OpenTofu templates designed to provision different kinds of Redis Enterprise Clusters across multiple cloud vendors.

**Currently supported cloud providers:**
- Amazon Web Services (AWS)
- Google Cloud Platform (GCP)
- Microsoft Azure

**Deployment options:**
- Virtual Machines (VMs)
- Managed Services (e.g., Azure Cache for Redis)
- Kubernetes (e.g., GKE)

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Cloud Provider Setup](#cloud-provider-setup)
- [Redis Enterprise Architecture](#redis-enterprise-architecture)
- [Available Configurations](#available-configurations)
- [Deployment Methods](#deployment-methods)
- [Advanced Options](#advanced-options)
- [Documentation](#documentation)

## Prerequisites

- Install [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) or [OpenTofu](https://opentofu.org/docs/intro/install/)
- Create an SSH key file (`~/.ssh/id_rsa`)
- Cloud provider credentials (see [Cloud Provider Setup](#cloud-provider-setup))

## 🚀 Quick Start

### Step 1: Configure Your Environment

Create your `.env` file from the template:

```bash
cp .env.sample .env
```

Edit `.env` and configure the required variables:

```bash
# Required: Your owner tag (format: firstname_lastname)
OWNER=thomas_manson

# Required: Redis Enterprise download base URL
# This is your private mirror or download source
REDIS_DOWNLOAD_BASE_URL=https://your-private-mirror.com/redis-enterprise

# Required: Redis Enterprise OS distribution
# Supported: jammy (Ubuntu 22.04), focal (Ubuntu 20.04), rhel8, rhel9
REDIS_OS=jammy

# Required: System architecture
# Supported: amd64, arm64
REDIS_ARCHITECTURE=amd64

# Optional: Redis Enterprise version (auto-detected if not set)
# REDIS_VERSION=8.0.6
# REDIS_BUILD=54

# Optional: Direct URL override (auto-constructed if not set)
# REDIS_ENTERPRISE_URL=https://your-mirror.com/redis/8.0.6/redislabs-8.0.6-54-jammy-amd64.tar

# Required: Cloud provider credentials (choose one)
# For AWS:
AWS_CREDENTIALS_FILE=/path/to/aws-credentials.sh

# For GCP:
GCP_CREDENTIALS_FILE=/path/to/gcp-credentials.json
GCP_PROJECT_ID=your-gcp-project-id

# For Azure:
AZURE_CREDENTIALS_FILE=/path/to/azure-credentials.sh
```

**Important:** All credentials should be stored in external files, not directly in `.env`.

#### Redis Version Management

The project supports **automatic version detection** for Redis Enterprise:

**Automatic Mode (Recommended):**
- Just set `REDIS_OS` and `REDIS_ARCHITECTURE`
- The latest Redis Enterprise version is automatically detected from redis.io
- The download URL is automatically constructed

**Manual Mode:**
- Set `REDIS_VERSION` and `REDIS_BUILD` for a specific version
- Or set `REDIS_ENTERPRISE_URL` directly for complete control

**Check Latest Version:**
```bash
./scripts/get_latest_redis_version.sh
```

This will show:
```
=========================================
Redis Enterprise Latest Version
=========================================
Full version:    8.0.6-54
Version number:  8.0.6
Build number:    54
=========================================
```

### Step 2: Verify Your Setup

Run the verification script to ensure everything is configured correctly:

```bash
./scripts/verify_setup.sh
```

**What this script checks:**
1. ✅ `.env.sample` exists
2. ✅ `.env` file exists and has required variables (`OWNER`, `REDIS_OS`, `REDIS_ARCHITECTURE`)
3. ✅ `.env` is properly excluded in `.gitignore`
4. ✅ All `variables.tf` files have `owner` and `skip_deletion` variables
5. ✅ All `.tf.json` configuration files have `locals` block for tags
6. ✅ All configuration directories have deployment scripts (`tofu_apply.sh`, `tofu_destroy.sh`)
7. ✅ Template scripts exist in `scripts/` directory
8. ✅ Documentation files exist

You should see:
```
✓ All checks passed! Setup is complete.
```

### Step 3: Deploy Infrastructure

#### Option A: Use the Interactive Menu (Recommended)

Run the deployment menu from the project root:

```bash
./deploy.sh
```

This will show you an interactive menu with all available configurations. After selecting a configuration, you'll be asked whether to **deploy** or **destroy** the infrastructure.

#### Option B: Use Quick Deploy Scripts

Run any of the quick deploy scripts from the project root:

```bash
# Deploy (create/update)
./aws_mono_region_rack_aware.sh
./gcp_mono_region_basic.sh
./azure_acre_enterprise.sh

# Destroy infrastructure (add --destroy flag)
./aws_mono_region_rack_aware.sh --destroy
./gcp_mono_region_basic.sh --destroy
./azure_acre_enterprise.sh --destroy
```

#### Option C: Navigate to Configuration Directory

Navigate to any configuration directory and deploy/destroy:

```bash
# Example: Deploy an AWS Rack-Aware Cluster
cd main/AWS/Mono-Region/Rack_Aware_Cluster
./tofu_apply.sh

# Example: Destroy the cluster
./tofu_destroy.sh
```

All methods will:
- ✅ Automatically detect the cloud provider (AWS, GCP, or Azure)
- ✅ Load your credentials from `.env`
- ✅ Tag all resources with `owner` and `skip_deletion`
- ✅ Deploy the infrastructure

### Destroy Infrastructure

When you're done, you can destroy the infrastructure from the configuration directory:

```bash
cd main/AWS/Mono-Region/Rack_Aware_Cluster
./tofu_destroy.sh
```

## Cloud Provider Setup

### AWS Setup

1. Download an [AWS service account key file](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)
2. Create a credentials file (e.g., `~/.cred/aws.sh`) with the following content:

```bash
export KEY="your-aws-access-key"
export SEC="your-aws-secret-key"
```

3. Configure the path in your `.env` file:

```bash
AWS_CREDENTIALS_FILE=~/.cred/aws.sh
```

### GCP Setup

1. Download a [GCP service account key file](https://cloud.google.com/iam/docs/creating-managing-service-account-keys) (JSON format)
2. Configure the credentials in your `.env` file:

```bash
GCP_CREDENTIALS_FILE=/path/to/gcp/credentials.json
GCP_PROJECT_ID=your-gcp-project-id
```

### Azure Setup

1. Create a service principal with at least the "Contributor" role:

```bash
az ad sp create-for-rbac --name <service_principal_name> --role Contributor --scopes /subscriptions/<subscription_id>
```

**Important:** You might not be able to create a service principal if your Azure credentials are set to "contributor". If this is the case, the creation will fail with an authorization error.

2. Create a credentials file (e.g., `~/.cred/azure.sh`) with the following content:

```bash
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
```

3. Configure the path in your `.env` file:

```bash
AZURE_CREDENTIALS_FILE=~/.cred/azure.sh
```

## Redis Enterprise Architecture

A Redis Enterprise cluster is composed of identical nodes that are deployed within a data center or stretched across local availability zones. Redis Enterprise architecture is made up of a management path (shown in the blue layer in the figure below) and data access path (shown in the red layer in the figure below).

![Redis Enterprise](https://cloudblogs.microsoft.com/wp-content/uploads/sites/37/2019/06/Redis_image-1-1024x293.png)

**Management path** includes the cluster manager, proxy and secure REST API/UI for programmatic administration. In short, cluster manager is responsible for orchestrating the cluster, placement of database shards as well as detecting and mitigating failures. Proxy helps scale connection management.

**Data Access path** is composed of master and replica Redis shards. Clients perform data operations on the master shard. Master shards maintain replica shards using the in-memory replication for protection against failures that may render master shard inaccessible.

![Nodes, shards and clusters and Redis databases](https://redislabs.com/wp-content/uploads/2019/06/blog-volkov-20190625-1-v5.png)


## 📚 Available Configurations

### Quick Deploy Scripts (from project root)

All configurations can be deployed or destroyed using quick scripts from the project root.

**Usage:**
```bash
# Deploy infrastructure
./script_name.sh

# Destroy infrastructure
./script_name.sh --destroy
```

**AWS:**
- `./aws_mono_region_basic.sh` - Single availability zone
- `./aws_mono_region_rack_aware.sh` - Multiple availability zones
- `./aws_cross_region_basic.sh` - Multi-region, single AZ per region
- `./aws_cross_region_rack_aware.sh` - Multi-region, multi-AZ

**GCP:**
- `./gcp_mono_region_basic.sh` - Single zone
- `./gcp_mono_region_rack_aware.sh` - Multiple zones
- `./gcp_cross_region_basic.sh` - Multi-region, single zone per region
- `./gcp_cross_region_rack_aware.sh` - Multi-region, multi-zone

**GCP GKE (Kubernetes):**
- `./gcp_gke_mono_region_basic.sh`
- `./gcp_gke_mono_region_rack_aware.sh`
- `./gcp_gke_cross_region_basic.sh`
- `./gcp_gke_cross_region_rack_aware.sh`

**Azure:**
- `./azure_mono_region_basic.sh` - Single availability zone
- `./azure_mono_region_rack_aware.sh` - Multiple availability zones
- `./azure_cross_region_basic.sh` - Multi-region, single AZ per region
- `./azure_cross_region_rack_aware.sh` - Multi-region, multi-AZ

**Azure ACRE (Managed Service):**
- `./azure_acre_enterprise.sh` - Azure Cache for Redis Enterprise
- `./azure_acre_oss.sh` - Azure Cache for Redis OSS

### Configuration Directories

If you prefer to navigate to the configuration directories:

**AWS:**
- `main/AWS/Mono-Region/Basic_Cluster`
- `main/AWS/Mono-Region/Rack_Aware_Cluster`
- `main/AWS/Cross-Region/Basic_Clusters`
- `main/AWS/Cross-Region/Rack_Aware_Clusters`

**GCP:**
- `main/GCP/Mono-Region/Basic_Cluster`
- `main/GCP/Mono-Region/Rack_Aware_Cluster`
- `main/GCP/Cross-Region/Basic_Clusters`
- `main/GCP/Cross-Region/Rack_Aware_Clusters`
- `main/GCP/GKE/Mono-Region/Basic_Cluster`
- `main/GCP/GKE/Mono-Region/Rack_Aware_Cluster`
- `main/GCP/GKE/Cross-Region/Basic_Clusters`
- `main/GCP/GKE/Cross-Region/Rack_Aware_Clusters`

**Azure:**
- `main/Azure/Mono-Region/Basic_Cluster`
- `main/Azure/Mono-Region/Rack_Aware_Cluster`
- `main/Azure/Cross-Region/Basic_Clusters`
- `main/Azure/Cross-Region/Rack_Aware_Clusters`
- `main/Azure/ACRE/Enterprise`
- `main/Azure/ACRE/OSS`

### Redis Enterprise on Virtual Machines

Each configuration consists of one (or many) JSON file(s) (tf.json) that calls one or many modules depending on the configuration. For each cloud provider, there exists:

- **Networking module** - Creates VPCs/VNETs and subnets
- **DNS module** - Creates the cluster's FQDN (NS record) and cluster nodes domain names (A records)
- **Redis Enterprise (re) module** - Creates the cluster nodes
- **Bastion module** - Creates a client machine with pre-installed packages (memtier, redis-cli, Prometheus, Grafana)
- **Other modules** - For specific purposes like peering or keypair management

### Redis Enterprise on Kubernetes

Another way to deploy Redis Enterprise is to use the Redis Enterprise [Operator](https://docs.redis.com/latest/kubernetes/architecture/operator/) for Kubernetes. It provides a simple way to get a Redis Enterprise cluster on Kubernetes and enables more complex deployment scenarios.

The Operator allows Redis to maintain a unified deployment solution across various Kubernetes environments:
- RedHat OpenShift
- VMware Tanzu (TKG and TKGI, formerly PKS)
- Google Kubernetes Engine (GKE)
- Azure Kubernetes Service (AKS)
- Vanilla (upstream) Kubernetes

StatefulSet and anti-affinity guarantee that each Redis Enterprise node resides on a Pod that is hosted on a different VM or physical server.

![Operator](https://www.odbms.org/wp-content/uploads/2018/09/Redis12.png)

#### Kubernetes Prerequisites

To deploy Redis Enterprise on Kubernetes, you'll need:
- The cloud provider's CLI ([gcloud](https://cloud.google.com/sdk/gcloud), [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/), [AWS CLI](https://aws.amazon.com/cli/))
- A Kubernetes client ([kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/))

## Deployment Methods

### Method 1: Interactive Menu

```bash
./deploy.sh
```

Select from a numbered list of all 18 available configurations. After selecting a configuration, choose whether to **deploy** or **destroy** the infrastructure.

### Method 2: Quick Deploy Scripts

```bash
# Deploy infrastructure
./aws_mono_region_rack_aware.sh

# Destroy infrastructure
./aws_mono_region_rack_aware.sh --destroy
```

Direct deployment/destruction from the project root without navigation.

### Method 3: Traditional Navigation

```bash
cd main/AWS/Mono-Region/Rack_Aware_Cluster
tofu init
tofu plan
tofu apply

# Or to destroy:
tofu destroy
```

Or use the provided scripts:

```bash
cd main/AWS/Mono-Region/Rack_Aware_Cluster
./tofu_apply.sh
```

## 🔧 Advanced Options

### Auto-Approve Mode

To skip confirmation prompts, add to your `.env`:

```bash
AUTO_APPROVE=yes
```

### Custom Deployment Name

Override the default deployment name:

```bash
DEPLOYMENT_NAME=my-custom-deployment
```

### Skip Deletion Tag

Protect resources from deletion:

```bash
SKIP_DELETION=yes
```

### Toggle Sensitive Output (Demo/POC Mode)

By default, Terraform/OpenTofu hides sensitive values (like passwords) in logs. For demo or POC environments where transparency is more important than security, you can toggle this behavior:

```bash
# Check current mode
./scripts/toggle_sensitive.sh status

# Enable DEMO mode (show all logs, including sensitive values)
./scripts/toggle_sensitive.sh show

# Enable PRODUCTION mode (hide sensitive values in logs)
./scripts/toggle_sensitive.sh hide
```

### Client Machine Features

If a client is added and enabled (the rs-client block added to the configuration file), a standalone machine will be created in the same VPC as the cluster containing:

- [memtier_benchmark](https://github.com/RedisLabs/memtier_benchmark) - Load generation and benchmarking for NoSQL key-value databases
- [Redis Stack](https://redis.io/docs/stack/) - Fully-extensive developer experience with Redis CLI, Redis modules, and RedisInsight
- [Prometheus](https://prometheus.io/) - Scrape time-series metrics exposed by the Redis `metrics_exporter` (on port 8070)
- [Grafana](https://grafana.com/grafana/) - Query, visualize, and alert on metrics scraped by Prometheus

![Prometheus](https://prometheus.io/assets/docs/architecture.svg)

### Private Configuration

If the configuration is set as private (`private_conf` set to true), the cluster will be created in one or many private subnets and will be reachable only by a bastion node. This configuration will create a NAT (Network Address Translation) gateway, so the cluster nodes in the private subnet(s) can connect to services outside the VPC but external services cannot initiate a connection with those instances.

## 📖 Documentation

All detailed documentation is organized in the [`augment/`](augment/) directory:

### User Guides
- [DEPLOYMENT_SHORTCUTS.md](augment/DEPLOYMENT_SHORTCUTS.md) - Detailed documentation on quick deploy scripts
- [SHORTCUTS_REFERENCE.md](augment/SHORTCUTS_REFERENCE.md) - Quick reference for all deployment shortcuts
- [TAGGING_AND_CREDENTIALS.md](augment/TAGGING_AND_CREDENTIALS.md) - Comprehensive guide on tagging and credentials management

### Technical Documentation
- [IMPLEMENTATION_SUMMARY.md](augment/IMPLEMENTATION_SUMMARY.md) - Technical implementation details

### Changelogs
- [CHANGELOG_REDIS_VERSION_AUTOMATION.md](augment/CHANGELOG_REDIS_VERSION_AUTOMATION.md) - Redis version auto-detection system (2026-01-07)
- [CHANGELOG_FINAL_UPDATES.md](augment/CHANGELOG_FINAL_UPDATES.md) - Final documentation updates (2026-01-06)
- [CHANGELOG_README_MIGRATION.md](augment/CHANGELOG_README_MIGRATION.md) - README migration from AsciiDoc to Markdown
- [CHANGELOG_REDIS_URL.md](augment/CHANGELOG_REDIS_URL.md) - Redis Enterprise URL centralization changes
- [CHANGELOG_DEPLOYMENT_SHORTCUTS.md](augment/CHANGELOG_DEPLOYMENT_SHORTCUTS.md) - Deployment shortcuts implementation details
- [CHANGELOG_TAGGING.md](augment/CHANGELOG_TAGGING.md) - Tagging and credentials management implementation

📚 **See [augment/README.md](augment/README.md) for a complete documentation index.**

## 📝 Important Notes

### Terraform State

The terraform state file is currently maintained locally. This means:
- Only one deployment is supported for each directory where the script is executed (terraform state file)
- Deployments created by other individuals will not be updatable

### Resource Tagging

All cloud resources must be tagged with:
- `owner` - Your name in format `firstname_lastname` (e.g., `thomas_manson`)
- `skip_deletion` - Set to `yes` for resources that should not be deleted

### Security

**Never commit credentials to version control!** The `.env` file is already added to `.gitignore` and will not be committed.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file.

## 🔗 Links

- [Redis Enterprise Documentation](https://docs.redis.com/latest/)
- [Terraform Documentation](https://www.terraform.io/docs)
- [OpenTofu Documentation](https://opentofu.org/docs/)


