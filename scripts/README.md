# Scripts Directory

This directory contains utility scripts for managing Redis Enterprise deployments across multiple cloud providers.

## Core Scripts

### `tofu_apply_template.sh`

Template script for applying Terraform/OpenTofu configurations.

**Features:**
- Loads configuration from `.env` file
- Auto-detects Redis Enterprise version if not specified
- Validates OS and architecture settings
- Constructs Redis download URL automatically
- Handles cloud-specific credentials (AWS, GCP, Azure)
- Passes tags and variables to Terraform/OpenTofu

**Usage:**
This is a template script. Each deployment directory has its own `tofu_apply.sh` that sources this template.

### `tofu_destroy_template.sh`

Template script for destroying Terraform/OpenTofu configurations.

**Features:**
- Same as `tofu_apply_template.sh` but for destruction
- Ensures consistent variable passing during destroy operations

**Usage:**
This is a template script. Each deployment directory has its own `tofu_destroy.sh` that sources this template.

## Version Management

### `get_latest_redis_version.sh`

Automatically detects the latest Redis Enterprise version from redis.io.

**Features:**
- Scrapes Redis release notes pages
- Detects latest major version (e.g., 8.0)
- Extracts latest full version (e.g., 8.0.6-54)
- Compatible with macOS (BSD) and Linux (GNU) tools
- Exports version variables for use in other scripts

**Usage:**
```bash
# Run directly to see the latest version
./scripts/get_latest_redis_version.sh

# Source to get environment variables
source ./scripts/get_latest_redis_version.sh
echo $REDIS_VERSION  # e.g., 8.0.6
echo $REDIS_BUILD    # e.g., 54
```

**Output:**
```
=========================================
Redis Enterprise Latest Version
=========================================
Full version:    8.0.6-54
Version number:  8.0.6
Build number:    54
=========================================
```

## Verification

### `verify_setup.sh`

Verifies that the project is correctly configured.

**What it checks:**
1. `.env.sample` exists
2. `.env` file exists and has required variables
3. `.env` is in `.gitignore`
4. All `variables.tf` files have required variables
5. All `.tf.json` files have locals block
6. All deployment directories have scripts
7. Template scripts exist
8. Documentation files exist

**Usage:**
```bash
./scripts/verify_setup.sh
```

**Expected output:**
```
✓ All checks passed! Setup is complete.
```

## Testing

### `test_version_detection.sh`

Tests the Redis version detection system.

**What it tests:**
1. Version detection script execution
2. Version component extraction
3. URL construction
4. URL format validation
5. .env.test file loading
6. Different OS distributions
7. Different architectures

**Usage:**
```bash
./scripts/test_version_detection.sh
```

### `test_deployment_integration.sh`

Tests integration with deployment scripts.

**What it tests:**
1. Environment file loading
2. Version detection simulation
3. OS and architecture validation
4. URL construction
5. Different configuration combinations

**Usage:**
```bash
./scripts/test_deployment_integration.sh
```

## Environment Variables

### Required Variables

**OWNER**
- Your owner tag (format: firstname_lastname)
- Example: `OWNER=thomas_manson`

**REDIS_DOWNLOAD_BASE_URL**
- Base URL for Redis Enterprise downloads
- This is your private mirror or download source
- Example: `REDIS_DOWNLOAD_BASE_URL=https://your-private-mirror.com/redis-enterprise`

**REDIS_OS**
- Operating system distribution
- Supported: `jammy`, `focal`, `rhel8`, `rhel9`
- Example: `REDIS_OS=jammy`

**REDIS_ARCHITECTURE**
- System architecture
- Supported: `amd64`, `arm64`
- Example: `REDIS_ARCHITECTURE=amd64`

### Optional Variables

**REDIS_VERSION**
- Redis Enterprise version number
- Auto-detected if not set
- Example: `REDIS_VERSION=8.0.6`

**REDIS_BUILD**
- Redis Enterprise build number
- Auto-detected if not set
- Example: `REDIS_BUILD=54`

**REDIS_ENTERPRISE_URL**
- Direct download URL
- Auto-constructed from REDIS_DOWNLOAD_BASE_URL if not set
- Example: `REDIS_ENTERPRISE_URL=https://your-mirror.com/redis/8.0.6/redislabs-8.0.6-54-jammy-amd64.tar`

**DEPLOYMENT_NAME**
- Custom deployment name
- Optional, defaults to configuration-specific name
- Example: `DEPLOYMENT_NAME=my-deployment`

**SKIP_DELETION**
- Whether to skip deletion of resources
- Values: `yes`, `no`
- Default: `yes`
- Example: `SKIP_DELETION=yes`

## Workflow

### 1. Initial Setup

```bash
# Copy sample environment file
cp .env.sample .env

# Edit .env with your settings
vim .env

# Verify setup
./scripts/verify_setup.sh
```

### 2. Check Latest Redis Version

```bash
./scripts/get_latest_redis_version.sh
```

### 3. Deploy Infrastructure

```bash
# Use the deployment menu
./deploy.sh

# Or deploy directly
cd main/AWS/Mono-Region/Basic
./tofu_apply.sh
```

### 4. Run Tests (Optional)

```bash
# Test version detection
./scripts/test_version_detection.sh

# Test deployment integration
./scripts/test_deployment_integration.sh
```

## Troubleshooting

### Version Detection Fails

**Problem:** `get_latest_redis_version.sh` fails to detect version

**Solutions:**
1. Check internet connectivity
2. Verify redis.io is accessible
3. Set version manually in `.env`:
   ```bash
   REDIS_VERSION=8.0.6
   REDIS_BUILD=54
   ```

### Invalid URL Format

**Problem:** Constructed URL is invalid

**Solutions:**
1. Verify `REDIS_OS` is set correctly
2. Verify `REDIS_ARCHITECTURE` is set correctly
3. Set `REDIS_ENTERPRISE_URL` directly in `.env`

### Missing Credentials

**Problem:** Deployment fails due to missing credentials

**Solutions:**
1. Verify credential files exist
2. Check file paths in `.env`
3. Ensure credentials are properly formatted

## See Also

- [Main README](../README.md) - Project overview and quick start
- [CHANGELOG_REDIS_VERSION_AUTOMATION.md](../augment/CHANGELOG_REDIS_VERSION_AUTOMATION.md) - Version automation details
- [TESTING_REDIS_VERSION_AUTOMATION.md](../augment/TESTING_REDIS_VERSION_AUTOMATION.md) - Testing documentation

