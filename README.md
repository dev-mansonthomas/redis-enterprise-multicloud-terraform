# Redis Enterprise Multicloud with Terraform

<p align="center">
  <img src="https://img.shields.io/badge/Redis-DC382D?style=for-the-badge&logo=redis&logoColor=white" alt="Redis"/>
  <img src="https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white" alt="Terraform"/>
  <img src="https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white" alt="AWS"/>
  <img src="https://img.shields.io/badge/Google_Cloud-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white" alt="GCP"/>
  <img src="https://img.shields.io/badge/Microsoft_Azure-0078D4?style=for-the-badge&logo=microsoft-azure&logoColor=white" alt="Azure"/>
</p>

<p align="center">
  <a href="https://github.com/dev-mansonthomas/redis-enterprise-multicloud-terraform/graphs/contributors"><img src="https://img.shields.io/github/contributors/dev-mansonthomas/redis-enterprise-multicloud-terraform.svg" alt="Contributors"/></a>
  <a href="https://github.com/dev-mansonthomas/redis-enterprise-multicloud-terraform/network/members"><img src="https://img.shields.io/github/forks/dev-mansonthomas/redis-enterprise-multicloud-terraform.svg" alt="Forks"/></a>
  <a href="https://github.com/dev-mansonthomas/redis-enterprise-multicloud-terraform/stargazers"><img src="https://img.shields.io/github/stars/dev-mansonthomas/redis-enterprise-multicloud-terraform.svg" alt="Stars"/></a>
  <a href="https://github.com/dev-mansonthomas/redis-enterprise-multicloud-terraform/watchers"><img src="https://img.shields.io/github/watchers/dev-mansonthomas/redis-enterprise-multicloud-terraform.svg" alt="Watchers"/></a>
  <a href="https://github.com/dev-mansonthomas/redis-enterprise-multicloud-terraform/issues"><img src="https://img.shields.io/github/issues/dev-mansonthomas/redis-enterprise-multicloud-terraform.svg" alt="Issues"/></a>
  <a href="https://github.com/dev-mansonthomas/redis-enterprise-multicloud-terraform/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-BSD%203--Clause-blue.svg" alt="License"/></a>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> •
  <a href="#features">Features</a> •
  <a href="#configuration">Configuration</a> •
  <a href="#scripts">Scripts</a> •
  <a href="#appendices">Appendices</a>
</p>

---

## Overview

**This project offers a simple and efficient way to provisioning/destroy of Redis Enterprise Clusters on AWS/Azure/GCP with one command line.**

```bash
./aws_multi_az.sh                  # Deploy
./aws_multi_az.sh --destroy        # Destroy
```

## Features

| Feature | Description |
|---------|-------------|
| 🔄 **Auto-detection** | Latest Redis Enterprise version auto-detected & downloaded |
| 🖥️ **VMs** | Deploy on virtual machines across all 3 cloud providers |
| 🔧 **Bastion VM** | Includes memtier_benchmark, Grafana, Prometheus, RedisInsight |
| 📊 **Cluster Size** | 3 to 35 nodes |
| ⚡ **Redis Flex** | Redis Flex support with local NVMe storage |
| 🛡️ **Rack-zone Awareness** | RackZone awareness enabled on Redis Enterprise |
| 💰 **Cost Profiles** | Budget or Performance configurations |
| 🌍 **Topologies** | Mono-AZ, Multi-AZ, Cross-Region for Active-Active DB |
| 🔗 **Active-Active** | Create CRDB spanning 6 clusters (2 per cloud provider) |
| 🏷️ **Tagging** | All resources tagged with `owner` and `skip_deletion` |
| 📝 **Single Config** | One `.env` file for all deployments |

---

## Quick Start

### 1. Copy and configure `.env`

```bash
cp .env.sample .env
# Edit .env with your values, more details in this readme.md
```

### 2. Verify your setup

```bash
./scripts/verify_setup.sh
```

### 3. Deploy a cluster

```bash
# AWS Multi-AZ (Rack-Aware)
./aws_multi_az.sh

# GCP Single Zone
./gcp_mono_az.sh

# Azure Multi-Region Active-Active
./azure_multi_region_aa.sh
```

### 4. Destroy when done

```bash
#using the same script you used to create your cluster, add the --destroy flag to destroy it
./aws_multi_az.sh --destroy
```

---

## Available Scripts

| Provider | Mono-AZ | Multi-AZ | Multi-Region A-A |
|----------|---------|----------|------------------|
| **AWS** | `aws_mono_az.sh` | `aws_multi_az.sh` | `aws_multi_region_aa.sh` |
| **GCP** | `gcp_mono_az.sh` | `gcp_multi_az.sh` | `gcp_multi_region_aa.sh` |
| **Azure** | `azure_mono_az.sh` | `azure_multi_az.sh` | `azure_multi_region_aa.sh` |

---

## Configuration

The `.env` file is organized into logical sections. See `.env.sample` for full documentation.

### Cloud Provider Credentials

Create credential files in `~/.private/` for each provider you want to use.
Take the time to setup the 3 Cloud Providers credentials, it will save you time in the long run.

<details>
<summary><b>AWS Credentials</b></summary>

Create `~/.private/aws.sh`:
```bash
export KEY="your-aws-access-key"
export SEC="your-aws-secret-key"
```

Configure in `.env`:
```bash
AWS_CREDENTIALS_FILE=~/.private/aws.sh
```

📖 See [Appendix A: AWS Setup](#appendix-a-aws-setup) for detailed instructions.
</details>

<details>
<summary><b>GCP Credentials</b></summary>

Download a [service account key](https://cloud.google.com/iam/docs/creating-managing-service-account-keys) (JSON format).

Configure in `.env`:
```bash
GCP_CREDENTIALS_FILE=~/.private/gcp-service-account.json
GCP_PROJECT_ID=your-gcp-project-id
```

📖 See [Appendix B: GCP Setup](#appendix-b-gcp-setup) for detailed instructions.
</details>

<details>
<summary><b>Azure Credentials</b></summary>

**Option 1: Azure CLI (Recommended)**

```bash
az login
az account show --query id -o tsv  # Get subscription ID
```

Create `~/.private/azure.sh`:
```bash
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
```

**Option 2: Service Principal (CI/CD)**

```bash
az ad sp create-for-rbac --name thomas-manson-sp --role Contributor \
  --scopes /subscriptions/<subscription_id>
```

📖 See [Appendix C: Azure Setup](#appendix-c-azure-setup) for detailed instructions.
</details>

> 💡 **Tip:** Set up all 3 cloud providers once. You can then deploy to any cloud without additional configuration.

### General Cluster Configuration

```bash
# Required
OWNER=firstname_lastname      # Tag for resource ownership
CLUSTER_SIZE=3                # Number of nodes (3-35)
DEPLOYMENT_NAME=my-cluster    # Affects FQDN: my-cluster.aws.yourdomain.com

# Redis Enterprise
REDIS_DOWNLOAD_BASE_URL=https://s3.amazonaws.com/redis-enterprise-software-downloads
REDIS_OS=jammy               # jammy, focal, rhel8, rhel9, amzn2
REDIS_ARCHITECTURE=amd64     # amd64, arm64, x86_64
```

#### SSH Keys

Two SSH key variables exist because **Azure does NOT support ed25519**:

```bash
# For AWS & GCP (both support ed25519 and RSA)
SSH_PUBLIC_KEY=~/.ssh/id_ed25519.pub
SSH_PRIVATE_KEY=~/.ssh/id_ed25519

# For Azure (RSA only!)
AZURE_SSH_PUBLIC_KEY=~/.ssh/id_rsa.pub
AZURE_SSH_PRIVATE_KEY=~/.ssh/id_rsa
```

Generate an RSA key for Azure if needed:
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -C "azure"
```

#### Deployment Name & FQDN

The `DEPLOYMENT_NAME` affects:
- Cluster name in Redis Enterprise UI
- DNS records: `<deployment_name>.<hosted_zone>`

Example: `DEPLOYMENT_NAME=prod-redis` + `AWS_HOSTED_ZONE=aws.example.com` → `prod-redis.aws.example.com`

#### Redis Enterprise Version

The version is **auto-detected** from redis.io. To override:
```bash
REDIS_VERSION=8.0.6
REDIS_BUILD=54
```

### Performance vs Budget

The `.env.sample` includes cost comparisons for each cloud provider. Quick reference:

| Profile | AWS | GCP | Azure |
|---------|-----|-----|-------|
| **Budget** | `t3.2xlarge` | `e2-standard-4` | `Standard_D4s_v3` |
| **Performance** | `i4i.xlarge` | `n2-standard-8` + Local SSD | `Standard_L8s_v3` |

For Redis on Flash, use instances with **local NVMe**:
- AWS: `i3.*` or `i4i.*` instances
- GCP: `n2-*` with `GCP_LOCAL_SSD_COUNT > 0`
- Azure: `Standard_L*s_v3` instances

---

## DNS Configuration

Each cloud provider needs a hosted zone for DNS records. Configure delegation from your domain registrar.

### Setup Per Provider

| Provider | Variable | Example |
|----------|----------|---------|
| AWS Route53 | `AWS_HOSTED_ZONE` | `aws.example.com` |
| GCP Cloud DNS | `GCP_DOMAIN_NAME` | `gcp.example.com` |
| Azure DNS | `AZ_HOSTED_ZONE` + `AZ_DNS_RESOURCE_GROUP` | `azure.example.com` |

### Registrar Configuration

Add NS records in your domain registrar pointing each subdomain to the cloud provider's nameservers:

```
aws.example.com   → AWS Route53 nameservers
gcp.example.com   → GCP Cloud DNS nameservers
azure.example.com → Azure DNS nameservers
```

<details>
<summary><b>AWS Route53 - Get Nameservers</b></summary>

```bash
# Create hosted zone
aws route53 create-hosted-zone --name "aws.example.com" --caller-reference "$(date +%s)"

# Get nameservers
ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "aws.example.com" \
  --query "HostedZones[0].Id" --output text)
aws route53 get-hosted-zone --id $ZONE_ID --query "DelegationSet.NameServers" --output table
```
</details>

<details>
<summary><b>GCP Cloud DNS - Get Nameservers</b></summary>

```bash
# Create DNS zone
gcloud dns managed-zones create gcp-example-com \
  --dns-name="gcp.example.com." \
  --description="GCP subdomain"

# Get nameservers
gcloud dns managed-zones describe gcp-example-com --format="value(nameServers)"
```
</details>

<details>
<summary><b>Azure DNS - Get Nameservers</b></summary>

```bash
# Create resource group
az group create --name dns-rg --location westeurope

# Create DNS zone
az network dns zone create --resource-group dns-rg --name "azure.example.com"

# Get nameservers
az network dns zone show --resource-group dns-rg --name "azure.example.com" \
  --query nameServers --output table
```
</details>

### Example Zone File Format (BIND syntax)

If you edit your DNS zone file directly, add entries like this:

```dns
; AWS subdomain delegation
aws     10800   IN  NS  ns-123.awsdns-45.com.
aws     10800   IN  NS  ns-678.awsdns-90.net.
aws     10800   IN  NS  ns-111.awsdns-22.org.
aws     10800   IN  NS  ns-333.awsdns-44.co.uk.

; GCP subdomain delegation
gcp     10800   IN  NS  ns-cloud-c1.googledomains.com.
gcp     10800   IN  NS  ns-cloud-c2.googledomains.com.
gcp     10800   IN  NS  ns-cloud-c3.googledomains.com.
gcp     10800   IN  NS  ns-cloud-c4.googledomains.com.

; Azure subdomain delegation
azure   10800   IN  NS  ns1-01.azure-dns.com.
azure   10800   IN  NS  ns2-01.azure-dns.net.
azure   10800   IN  NS  ns3-01.azure-dns.org.
azure   10800   IN  NS  ns4-01.azure-dns.info.
```

> **Note**: The TTL (10800 = 3 hours) can be adjusted. Don't forget the trailing dot (.) after nameserver FQDNs.

---

## Utility Scripts

| Script | Description |
|--------|-------------|
| `scripts/verify_setup.sh` | Validate `.env` configuration and CLI tools |
| `scripts/get_latest_redis_version.sh` | Fetch latest Redis Enterprise version from redis.io |
| `scripts/aws_quota_check.sh` | List AWS vCPU quotas by region |
| `scripts/gcp_quota_check.sh` | List GCP CPU quotas by region |
| `scripts/azure_quota_check.sh` | List Azure vCPU quotas by region |
| `scripts/toggle_sensitive.sh` | Hide/show sensitive values in terraform output |

### Usage Examples

```bash
# Check quotas before deploying
./scripts/aws_quota_check.sh us-east-1
./scripts/gcp_quota_check.sh us-central1
./scripts/azure_quota_check.sh westeurope

# Get latest Redis version
./scripts/get_latest_redis_version.sh
```

---

## Appendices

### Appendix A: AWS Setup

#### Prerequisites

- AWS account with IAM permissions to create EC2, VPC, Route53 resources
- AWS CLI installed: `brew install awscli` (macOS) or see [AWS CLI docs](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

#### Step 1: Create IAM Access Keys

1. Go to [AWS IAM Console](https://console.aws.amazon.com/iam/)
2. Navigate to Users → Your User → Security credentials
3. Create access key → Select "CLI" use case
4. Download or copy the Access Key ID and Secret Access Key

#### Step 2: Create Credentials File

```bash
mkdir -p ~/.private
cat > ~/.private/aws.sh << 'EOF'
export KEY="xxxxxxxxxxxxx"
export SEC="yyyyyyyyyyyyy"
EOF
chmod 600 ~/.private/aws.sh
```

#### Step 3: Configure `.env`

```bash
AWS_CREDENTIALS_FILE=~/.private/aws.sh
AWS_REGION_NAME=us-east-1
```

#### Step 4: Verify

```bash
source ~/.private/aws.sh
aws sts get-caller-identity
```

---

### Appendix B: GCP Setup

#### Prerequisites

- GCP project with billing enabled
- `gcloud` CLI installed: `brew install google-cloud-sdk` (macOS) or see [gcloud docs](https://cloud.google.com/sdk/docs/install)

#### Step 1: Create a Service Account

```bash
# Set your project
gcloud config set project YOUR_PROJECT_ID

# Create service account
gcloud iam service-accounts create thomas-manson-sa \
  --display-name="Thomas Manson Service Account"

# Grant Compute Admin role
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:thomas-manson-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/compute.admin"

# Grant DNS Admin role (for DNS records)
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:thomas-manson-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/dns.admin"

# Grant Service Account User (for instances)
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:thomas-manson-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"
```

#### Step 2: Download Service Account Key

```bash
mkdir -p ~/.private
gcloud iam service-accounts keys create ~/.private/gcp-service-account.json \
  --iam-account=thomas-manson-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com
chmod 600 ~/.private/gcp-service-account.json
```

#### Step 3: Configure `.env`

```bash
GCP_CREDENTIALS_FILE=~/.private/gcp-service-account.json
GCP_PROJECT_ID=your-project-id
GCP_REGION_NAME=us-central1
```

#### Step 4: Verify

```bash
gcloud auth activate-service-account --key-file=~/.private/gcp-service-account.json
gcloud compute zones list --limit=5
```

---

### Appendix C: Azure Setup

#### Prerequisites

- Azure subscription
- Azure CLI installed: `brew install azure-cli` (macOS) or see [Azure CLI docs](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

#### Option 1: Azure CLI Authentication (Recommended)

Best for developers who don't have permission to create Service Principals.

```bash
# Login to Azure
az login

# Get your subscription ID
az account show --query id -o tsv

# Create credentials file
mkdir -p ~/.private
cat > ~/.private/azure.sh << 'EOF'
# Azure CLI auth - run 'az login' before deploying
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
EOF
chmod 600 ~/.private/azure.sh
```

> ⚠️ Remember to run `az login` before each deployment session.

#### Option 2: Service Principal (CI/CD Automation)

Requires `Owner` or `Application Administrator` role.

```bash
# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create service principal
az ad sp create-for-rbac \
  --name "thomas-manson-sp" \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID
```

Save the output:
```json
{
  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",      → AZURE_CLIENT_ID
  "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",     → AZURE_CLIENT_SECRET
  "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"      → AZURE_TENANT_ID
}
```

Create credentials file:
```bash
mkdir -p ~/.private
cat > ~/.private/azure.sh << 'EOF'
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
EOF
chmod 600 ~/.private/azure.sh
```

#### Configure `.env`

```bash
AZURE_CREDENTIALS_FILE=~/.private/azure.sh
AZ_REGION_NAME="East US"
```

#### Verify

```bash
# For CLI auth
az account show

# For Service Principal
source ~/.private/azure.sh
az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
```

---

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

