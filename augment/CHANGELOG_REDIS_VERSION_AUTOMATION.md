# Changelog: Redis Version Auto-Detection

## Date
2026-01-07

## Summary
Implementation of automatic Redis Enterprise version detection system to simplify version management and ensure compatibility with future Redis Enterprise releases, including support for different OS distributions and architectures.

## Problem Statement

Previously, users had to:
1. Manually check the Redis release notes for the latest version
2. Construct the download URL manually
3. Update the `.env` file with the complete URL
4. Repeat this process for every new Redis Enterprise release

This was error-prone and didn't scale well for:
- New minor versions (e.g., 8.0.7, 8.0.8)
- New major versions (e.g., 8.1, 9.0)
- Different OS distributions (Ubuntu versions, RHEL versions)
- Different architectures (amd64, arm64)

## Solution

Implemented an automated version detection and URL construction system with three components:

### 1. Version Detection Script (`scripts/get_latest_redis_version.sh`)

A bash script that:
- Scrapes the Redis release notes page (https://redis.io/docs/latest/operate/rs/release-notes/)
- Detects the latest major version (e.g., "8.0")
- Navigates to the major version page
- Extracts the latest full version (e.g., "8.0.6-54")
- Exports version components as environment variables

**Features:**
- Compatible with macOS (BSD) and Linux (GNU) tools
- Outputs to stderr for logging, stdout for easy capture
- Can be sourced or executed
- Automatically adapts to new Redis versions

### 2. Enhanced Environment Configuration (`.env.sample`)

New variables added:
```bash
# Redis Enterprise version (auto-detected if not set)
REDIS_VERSION=

# Redis Enterprise build number (auto-detected if not set)
REDIS_BUILD=

# Operating system distribution (REQUIRED)
REDIS_OS=jammy

# System architecture (REQUIRED)
REDIS_ARCHITECTURE=amd64

# Redis Enterprise download URL (auto-constructed)
REDIS_ENTERPRISE_URL=
```

**Supported OS distributions:**
- `jammy` - Ubuntu 22.04
- `focal` - Ubuntu 20.04
- `rhel8` - Red Hat Enterprise Linux 8
- `rhel9` - Red Hat Enterprise Linux 9

**Supported architectures:**
- `amd64` - x86_64 / AMD64
- `arm64` - ARM 64-bit (future support)

### 3. Updated Deployment Scripts

Both `tofu_apply_template.sh` and `tofu_destroy_template.sh` now:
1. Check if `REDIS_VERSION` and `REDIS_BUILD` are set
2. If not set, automatically run `get_latest_redis_version.sh`
3. Validate `REDIS_OS` and `REDIS_ARCHITECTURE` are set
4. Construct the download URL automatically:
   ```
   https://s3.amazonaws.com/redis-enterprise-software-downloads/{VERSION}/redislabs-{VERSION}-{BUILD}-{OS}-{ARCH}.tar
   ```

## Changes Made

### Files Created

**`scripts/get_latest_redis_version.sh`**
- Web scraping script for version detection
- Uses `curl`, `grep`, and `sed` for compatibility
- Exports `REDIS_VERSION`, `REDIS_BUILD`, and `REDIS_FULL_VERSION`

### Files Modified

**`.env.sample`**
- Added `REDIS_VERSION` variable
- Added `REDIS_BUILD` variable
- Added `REDIS_OS` variable (required)
- Added `REDIS_ARCHITECTURE` variable (required)
- Updated `REDIS_ENTERPRISE_URL` documentation
- Added examples and supported values

**`scripts/tofu_apply_template.sh`**
- Added automatic version detection logic
- Added OS and architecture validation
- Added automatic URL construction
- Improved error messages

**`scripts/tofu_destroy_template.sh`**
- Added automatic version detection logic
- Added OS and architecture validation
- Added automatic URL construction
- Improved error messages

**`scripts/verify_setup.sh`**
- Updated to check `REDIS_OS` and `REDIS_ARCHITECTURE`
- Updated to handle auto-detected versions
- Improved validation messages

## Usage Examples

### Automatic Version Detection (Recommended)

Create `.env` file with minimal configuration:
```bash
OWNER=thomas_manson
REDIS_OS=jammy
REDIS_ARCHITECTURE=amd64
```

The deployment scripts will automatically:
1. Detect the latest Redis version (e.g., 8.0.6-54)
2. Construct the URL
3. Deploy with the latest version

### Manual Version Specification

For specific version requirements:
```bash
OWNER=thomas_manson
REDIS_VERSION=8.0.6
REDIS_BUILD=54
REDIS_OS=jammy
REDIS_ARCHITECTURE=amd64
```

### Direct URL Override

For complete control:
```bash
OWNER=thomas_manson
REDIS_OS=jammy
REDIS_ARCHITECTURE=amd64
REDIS_ENTERPRISE_URL=https://s3.amazonaws.com/redis-enterprise-software-downloads/8.0.6/redislabs-8.0.6-54-jammy-amd64.tar
```

## Benefits

### For Users
- ✅ No need to manually check for new versions
- ✅ Automatic adaptation to new Redis releases
- ✅ Support for different OS distributions
- ✅ Support for different architectures
- ✅ Reduced configuration errors
- ✅ Simplified `.env` file

### For Maintainability
- ✅ Future-proof for Redis 8.1, 9.0, etc.
- ✅ Ready for ARM64 support
- ✅ Easy to add new OS distributions
- ✅ Centralized version management
- ✅ Consistent URL construction

### For Compatibility
- ✅ Works on macOS (BSD tools)
- ✅ Works on Linux (GNU tools)
- ✅ No external dependencies (curl, grep, sed)
- ✅ Backward compatible (can still use REDIS_ENTERPRISE_URL)

## Testing

Test the version detection script:
```bash
./scripts/get_latest_redis_version.sh
```

Expected output:
```
[INFO] Starting Redis Enterprise version detection...
[INFO] Fetching latest major version from Redis release notes...
[INFO] Latest major version: 8.0
[INFO] Fetching latest full version from https://redis.io/docs/latest/operate/rs/release-notes/rs-8-0-releases/...
[INFO] Latest full version: 8.0.6-54

=========================================
Redis Enterprise Latest Version
=========================================
Full version:    8.0.6-54
Version number:  8.0.6
Build number:    54
=========================================
```

## Migration Guide

### For Existing Users

1. **Update your `.env` file:**
   ```bash
   # Add these new variables
   REDIS_OS=jammy
   REDIS_ARCHITECTURE=amd64
   
   # Optional: Remove REDIS_ENTERPRISE_URL to use auto-detection
   # Or keep it for manual control
   ```

2. **Verify your setup:**
   ```bash
   ./scripts/verify_setup.sh
   ```

3. **Test deployment:**
   ```bash
   ./deploy.sh
   ```

### For New Users

1. Copy `.env.sample` to `.env`
2. Set `OWNER`, `REDIS_OS`, and `REDIS_ARCHITECTURE`
3. Run `./scripts/verify_setup.sh`
4. Deploy with `./deploy.sh`

## Future Enhancements

Potential improvements:
- Cache version detection results to reduce API calls
- Add version pinning for production deployments
- Support for custom download mirrors
- Validation of download URL availability
- Integration with CI/CD pipelines

## Related Changes

This change builds upon:
- [CHANGELOG_REDIS_URL.md](CHANGELOG_REDIS_URL.md) - Redis URL centralization
- [CHANGELOG_TAGGING.md](CHANGELOG_TAGGING.md) - Environment configuration system

