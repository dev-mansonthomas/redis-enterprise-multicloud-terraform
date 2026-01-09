# Changelog: Redis Download Base URL Security

## Date
2026-01-08

## Summary
Removed hardcoded Redis download base URL from scripts and made it a required configuration variable to protect private mirror URLs and improve security.

## Problem Statement

The Redis Enterprise download base URL (`https://s3.amazonaws.com/redis-enterprise-software-downloads/`) was **hardcoded** in multiple scripts:
- `scripts/tofu_apply_template.sh`
- `scripts/tofu_destroy_template.sh`
- `scripts/test_version_detection.sh`
- `scripts/test_deployment_integration.sh`

**Security Issues:**
1. ❌ Assumes public S3 bucket (not always the case)
2. ❌ Cannot use private mirrors without code changes
3. ❌ Exposes download source in version control
4. ❌ Not configurable per environment

## Solution

Introduced a new **required** environment variable: `REDIS_DOWNLOAD_BASE_URL`

### Key Principles
1. ✅ **No default value** - Scripts fail if not set
2. ✅ **User-controlled** - Each user sets their own mirror
3. ✅ **Private by default** - URL stays in `.env` (gitignored)
4. ✅ **Flexible** - Supports any download source

## Changes Made

### 1. New Environment Variable

**`.env.sample`**
```bash
# Redis Enterprise download base URL (REQUIRED)
# This is the base URL where Redis Enterprise packages are hosted
# Example: REDIS_DOWNLOAD_BASE_URL=https://your-private-mirror.com/redis-enterprise
REDIS_DOWNLOAD_BASE_URL=
```

### 2. Updated Deployment Scripts

**`scripts/tofu_apply_template.sh`** and **`scripts/tofu_destroy_template.sh`**

**BEFORE:**
```bash
if [ -z "$REDIS_ENTERPRISE_URL" ]; then
    REDIS_ENTERPRISE_URL="https://s3.amazonaws.com/redis-enterprise-software-downloads/${REDIS_VERSION}/redislabs-${REDIS_VERSION}-${REDIS_BUILD}-${REDIS_OS}-${REDIS_ARCHITECTURE}.tar"
    echo "Constructed Redis Enterprise URL: $REDIS_ENTERPRISE_URL"
fi
```

**AFTER:**
```bash
# Check Redis download base URL
if [ -z "$REDIS_DOWNLOAD_BASE_URL" ]; then
    echo "Error: REDIS_DOWNLOAD_BASE_URL variable is not set. Please set it in .env file."
    echo "Example: REDIS_DOWNLOAD_BASE_URL=https://your-private-mirror.com/redis-enterprise"
    exit 1
fi

# Construct Redis Enterprise URL if not explicitly set
if [ -z "$REDIS_ENTERPRISE_URL" ]; then
    REDIS_ENTERPRISE_URL="${REDIS_DOWNLOAD_BASE_URL}/${REDIS_VERSION}/redislabs-${REDIS_VERSION}-${REDIS_BUILD}-${REDIS_OS}-${REDIS_ARCHITECTURE}.tar"
    echo "Constructed Redis Enterprise URL: $REDIS_ENTERPRISE_URL"
fi
```

### 3. Updated Verification Script

**`scripts/verify_setup.sh`**

Added validation for `REDIS_DOWNLOAD_BASE_URL`:
```bash
# Check Redis download base URL
if [ -n "$REDIS_DOWNLOAD_BASE_URL" ]; then
    echo "   ✓ REDIS_DOWNLOAD_BASE_URL is set"
else
    echo "   ✗ REDIS_DOWNLOAD_BASE_URL is not set in .env"
    ERRORS=$((ERRORS + 1))
fi
```

### 4. Updated Test Scripts

**`scripts/test_version_detection.sh`**
- Skips URL construction tests if `REDIS_DOWNLOAD_BASE_URL` not set
- Shows warning message instead of failing
- Preserves `REDIS_DOWNLOAD_BASE_URL` when sourcing `.env.test`

**`scripts/test_deployment_integration.sh`**
- Requires `REDIS_DOWNLOAD_BASE_URL` to be set in environment
- Fails with clear error message if not set
- Uses the provided base URL for all tests

### 5. Updated Documentation

**`README.md`**
- Added `REDIS_DOWNLOAD_BASE_URL` as required variable
- Updated examples to use generic mirror URLs
- Removed references to public S3 URLs

**`scripts/README.md`**
- Documented `REDIS_DOWNLOAD_BASE_URL` as required
- Added examples and usage instructions

## Usage

### Minimal Configuration

```bash
# .env file
OWNER=thomas_manson
REDIS_DOWNLOAD_BASE_URL=https://your-private-mirror.com/redis-enterprise
REDIS_OS=jammy
REDIS_ARCHITECTURE=amd64
```

The deployment scripts will:
1. ✅ Validate `REDIS_DOWNLOAD_BASE_URL` is set
2. ✅ Auto-detect latest Redis version
3. ✅ Construct URL: `{BASE_URL}/{VERSION}/redislabs-{VERSION}-{BUILD}-{OS}-{ARCH}.tar`

### Example URLs

**Private S3 bucket:**
```bash
REDIS_DOWNLOAD_BASE_URL=https://my-company-bucket.s3.amazonaws.com/redis
```

**Internal mirror:**
```bash
REDIS_DOWNLOAD_BASE_URL=https://artifacts.company.internal/redis-enterprise
```

**CDN:**
```bash
REDIS_DOWNLOAD_BASE_URL=https://cdn.company.com/software/redis
```

## Security Benefits

### Before
- ❌ Public URL hardcoded in scripts
- ❌ Visible in version control
- ❌ Cannot use private mirrors
- ❌ Same URL for all users

### After
- ✅ URL configured per user
- ✅ Stays in `.env` (gitignored)
- ✅ Supports private mirrors
- ✅ Fails safely if not configured

## Migration Guide

### For Existing Users

1. **Add to your `.env` file:**
   ```bash
   REDIS_DOWNLOAD_BASE_URL=https://your-mirror.com/redis-enterprise
   ```

2. **Verify setup:**
   ```bash
   ./scripts/verify_setup.sh
   ```

3. **Test (optional):**
   ```bash
   export REDIS_DOWNLOAD_BASE_URL="https://your-mirror.com/redis"
   ./scripts/test_version_detection.sh
   ```

### For New Users

1. Copy `.env.sample` to `.env`
2. Set `REDIS_DOWNLOAD_BASE_URL` to your mirror URL
3. Set other required variables
4. Run `./scripts/verify_setup.sh`

## Error Handling

### Missing Variable

**Error message:**
```
Error: REDIS_DOWNLOAD_BASE_URL variable is not set. Please set it in .env file.
Example: REDIS_DOWNLOAD_BASE_URL=https://your-private-mirror.com/redis-enterprise
```

**Solution:**
Add `REDIS_DOWNLOAD_BASE_URL` to your `.env` file.

## Testing

All tests updated and passing:

**Without `REDIS_DOWNLOAD_BASE_URL`:**
- ✅ Version detection works
- ⚠️ URL construction tests skipped
- ℹ️ Clear warning messages

**With `REDIS_DOWNLOAD_BASE_URL`:**
- ✅ All tests pass
- ✅ URL construction validated
- ✅ Multiple OS/arch combinations tested

## Related Changes

This change builds upon:
- [CHANGELOG_REDIS_VERSION_AUTOMATION.md](CHANGELOG_REDIS_VERSION_AUTOMATION.md) - Version auto-detection
- [CHANGELOG_REDIS_URL.md](CHANGELOG_REDIS_URL.md) - URL centralization

## Conclusion

The Redis download base URL is now:
- ✅ **Configurable** - Set per user/environment
- ✅ **Secure** - Not exposed in version control
- ✅ **Required** - Scripts fail if not set
- ✅ **Flexible** - Supports any download source

This improves security and flexibility while maintaining ease of use.

