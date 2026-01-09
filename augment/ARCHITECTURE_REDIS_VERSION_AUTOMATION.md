# Architecture: Redis Version Auto-Detection System

## Date
2026-01-07

## Overview

This document describes the architecture of the Redis version auto-detection system, including components, data flow, and design decisions.

## System Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                         User Layer                          │
├─────────────────────────────────────────────────────────────┤
│  deploy.sh  │  tofu_apply.sh  │  tofu_destroy.sh           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Configuration Layer                      │
├─────────────────────────────────────────────────────────────┤
│  .env file                                                  │
│  ├─ OWNER (required)                                        │
│  ├─ REDIS_OS (required)                                     │
│  ├─ REDIS_ARCHITECTURE (required)                           │
│  ├─ REDIS_VERSION (optional)                                │
│  ├─ REDIS_BUILD (optional)                                  │
│  └─ REDIS_ENTERPRISE_URL (optional)                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Processing Layer                         │
├─────────────────────────────────────────────────────────────┤
│  tofu_apply_template.sh / tofu_destroy_template.sh          │
│  ├─ Load .env                                               │
│  ├─ Check if version is set                                 │
│  ├─ Auto-detect if needed                                   │
│  ├─ Validate OS and architecture                            │
│  └─ Construct URL if needed                                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Version Detection Layer                    │
├─────────────────────────────────────────────────────────────┤
│  get_latest_redis_version.sh                                │
│  ├─ Scrape redis.io release notes                           │
│  ├─ Extract major version                                   │
│  ├─ Scrape version-specific page                            │
│  ├─ Extract full version                                    │
│  └─ Export environment variables                            │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Deployment Layer                         │
├─────────────────────────────────────────────────────────────┤
│  Terraform / OpenTofu                                       │
│  └─ Receives rs_release variable                            │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

### Scenario 1: Automatic Version Detection

```
User runs deploy.sh
    │
    ├─> Load .env (REDIS_OS=jammy, REDIS_ARCHITECTURE=amd64)
    │
    ├─> Check REDIS_VERSION → Not set
    │
    ├─> Run get_latest_redis_version.sh
    │   │
    │   ├─> Fetch https://redis.io/docs/latest/operate/rs/release-notes/
    │   │   └─> Extract: "8.0"
    │   │
    │   ├─> Fetch https://redis.io/docs/latest/operate/rs/release-notes/rs-8-0-releases/
    │   │   └─> Extract: "8.0.6-54"
    │   │
    │   └─> Export: REDIS_VERSION=8.0.6, REDIS_BUILD=54
    │
    ├─> Validate REDIS_OS → OK
    │
    ├─> Validate REDIS_ARCHITECTURE → OK
    │
    ├─> Construct URL:
    │   https://s3.amazonaws.com/redis-enterprise-software-downloads/8.0.6/redislabs-8.0.6-54-jammy-amd64.tar
    │
    └─> Pass to Terraform/OpenTofu
```

### Scenario 2: Manual Version Specification

```
User runs deploy.sh
    │
    ├─> Load .env (REDIS_VERSION=8.0.6, REDIS_BUILD=54, REDIS_OS=jammy, REDIS_ARCHITECTURE=amd64)
    │
    ├─> Check REDIS_VERSION → Set
    │
    ├─> Skip version detection
    │
    ├─> Validate REDIS_OS → OK
    │
    ├─> Validate REDIS_ARCHITECTURE → OK
    │
    ├─> Construct URL:
    │   https://s3.amazonaws.com/redis-enterprise-software-downloads/8.0.6/redislabs-8.0.6-54-jammy-amd64.tar
    │
    └─> Pass to Terraform/OpenTofu
```

### Scenario 3: Direct URL Override

```
User runs deploy.sh
    │
    ├─> Load .env (REDIS_ENTERPRISE_URL=https://..., REDIS_OS=jammy, REDIS_ARCHITECTURE=amd64)
    │
    ├─> Check REDIS_ENTERPRISE_URL → Set
    │
    ├─> Skip version detection
    │
    ├─> Skip URL construction
    │
    └─> Pass to Terraform/OpenTofu
```

## Design Decisions

### 1. Web Scraping vs. API

**Decision:** Use web scraping

**Rationale:**
- Redis doesn't provide a public API for version information
- Release notes pages have a consistent structure
- Scraping is reliable and fast enough for deployment workflows

**Trade-offs:**
- ✅ No API key required
- ✅ No rate limiting
- ⚠️ Vulnerable to website structure changes
- ⚠️ Requires network access

### 2. BSD vs. GNU Tools

**Decision:** Support both BSD (macOS) and GNU (Linux) tools

**Rationale:**
- Developers use macOS
- Production deployments often use Linux
- Maximum compatibility

**Implementation:**
- Use basic grep/sed syntax
- Avoid Perl-compatible regex (-P flag)
- Test on both platforms

### 3. Environment Variables vs. Command-Line Arguments

**Decision:** Use environment variables from .env file

**Rationale:**
- Consistent with existing credential management
- Easy to version control (with .env in .gitignore)
- Supports multiple deployment configurations

**Trade-offs:**
- ✅ Secure (credentials not in command history)
- ✅ Easy to manage
- ⚠️ Requires .env file setup

### 4. Auto-Detection vs. Manual Configuration

**Decision:** Support both modes

**Rationale:**
- Auto-detection for convenience
- Manual configuration for control
- Flexibility for different use cases

**Use cases:**
- Auto-detection: Development, testing, latest version
- Manual: Production, specific version requirements, offline deployments

### 5. URL Construction vs. Direct URL

**Decision:** Support both approaches

**Rationale:**
- URL construction for standard deployments
- Direct URL for custom mirrors or special cases

**Benefits:**
- ✅ Flexibility
- ✅ Future-proof
- ✅ Supports custom download sources

## Error Handling

### Network Failures

**Scenario:** redis.io is unreachable

**Handling:**
- curl fails silently
- Version extraction returns empty string
- Script exits with error message
- User can set version manually

### Invalid Version Format

**Scenario:** Redis changes version format

**Handling:**
- Regex fails to match
- Script exits with error message
- User can set REDIS_ENTERPRISE_URL directly

### Missing Environment Variables

**Scenario:** Required variables not set

**Handling:**
- Deployment script checks for required variables
- Clear error messages with examples
- Script exits before Terraform/OpenTofu runs

## Security Considerations

### 1. No Credentials in Scripts

- All credentials in external files
- .env file in .gitignore
- No default credentials

### 2. HTTPS Only

- All downloads use HTTPS
- S3 URLs are verified

### 3. No Code Execution from Web

- Only data extraction
- No eval or exec of downloaded content

## Performance

### Version Detection

- **Time:** ~2-3 seconds
- **Network:** 2 HTTP requests
- **Data:** ~100KB total
- **Caching:** Not implemented (future enhancement)

### Deployment Scripts

- **Overhead:** Minimal (~2-3 seconds for auto-detection)
- **Impact:** Negligible in deployment workflow

## Extensibility

### Adding New OS Distributions

1. Add to supported list in .env.sample
2. Update documentation
3. No code changes required

### Adding New Architectures

1. Add to supported list in .env.sample
2. Update documentation
3. No code changes required

### Supporting New Redis Versions

- Automatic (no changes required)
- Works with any version format: X.Y.Z-BUILD

### Custom Download Sources

- Set REDIS_ENTERPRISE_URL directly
- No code changes required

## Testing Strategy

### Unit Tests

- Version detection script
- URL construction
- Environment variable handling

### Integration Tests

- End-to-end deployment simulation
- Different configuration scenarios
- Error handling

### Compatibility Tests

- macOS (BSD tools)
- Linux (GNU tools)
- Different shell versions

## Future Enhancements

### 1. Caching

- Cache version detection results
- Reduce network requests
- Configurable cache duration

### 2. Validation

- Verify download URL exists
- Check file size/checksum
- Validate before deployment

### 3. Offline Mode

- Support for offline deployments
- Local version database
- Manual version specification

### 4. CI/CD Integration

- GitHub Actions support
- GitLab CI support
- Jenkins support

## Conclusion

The Redis version auto-detection system is designed to be:
- **Simple:** Easy to understand and use
- **Flexible:** Multiple configuration modes
- **Robust:** Error handling and validation
- **Extensible:** Easy to add new features
- **Maintainable:** Clear architecture and documentation

The architecture supports current needs while allowing for future enhancements.

