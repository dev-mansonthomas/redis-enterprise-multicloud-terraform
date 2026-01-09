# Documentation Directory

This directory contains detailed documentation and changelogs for the TerraMine project.

## 📚 Documentation Files

### User Guides

- **[DEPLOYMENT_SHORTCUTS.md](DEPLOYMENT_SHORTCUTS.md)** - Comprehensive guide on using quick deployment scripts
  - Interactive menu usage
  - Script naming patterns
  - Usage examples for all cloud providers
  - How the scripts work internally

- **[SHORTCUTS_REFERENCE.md](SHORTCUTS_REFERENCE.md)** - Quick reference card for all deployment shortcuts
  - All 18 available scripts listed
  - Quick command reference
  - Prerequisites checklist
  - Tips and troubleshooting

- **[TAGGING_AND_CREDENTIALS.md](TAGGING_AND_CREDENTIALS.md)** - Complete guide on tagging and credentials management
  - Environment configuration setup
  - Cloud provider credentials configuration (AWS, GCP, Azure)
  - Tagging requirements and compliance
  - Security best practices
  - Troubleshooting guide

### Technical Documentation

- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Technical implementation details
  - Overview of all changes made to the project
  - File-by-file modification summary
  - Tag flow and architecture
  - Module updates across AWS, GCP, and Azure
  - Compliance verification

## 📝 Changelogs

### [CHANGELOG_README_MIGRATION.md](CHANGELOG_README_MIGRATION.md)
**Date:** 2026-01-06

Migration of the main documentation from AsciiDoc (`README.adoc`) to Markdown (`README.md`).

**Key Changes:**
- Created comprehensive README.md combining multiple documentation sources
- Updated `.env.sample` to remove direct credentials and use only file references
- Updated all documentation cross-references
- Improved security by removing default credential values

### [CHANGELOG_REDIS_VERSION_AUTOMATION.md](CHANGELOG_REDIS_VERSION_AUTOMATION.md)
**Date:** 2026-01-07

Implementation of automatic Redis Enterprise version detection system.

**Key Changes:**
- Created `scripts/get_latest_redis_version.sh` for automatic version detection
- Added `REDIS_VERSION`, `REDIS_BUILD`, `REDIS_OS`, and `REDIS_ARCHITECTURE` variables
- Updated deployment scripts to auto-detect and construct Redis download URLs
- Support for multiple OS distributions (Ubuntu, RHEL) and architectures (amd64, arm64)
- Future-proof for new Redis Enterprise versions

**Related Documentation:**
- [ARCHITECTURE_REDIS_VERSION_AUTOMATION.md](ARCHITECTURE_REDIS_VERSION_AUTOMATION.md) - System architecture
- [TESTING_REDIS_VERSION_AUTOMATION.md](TESTING_REDIS_VERSION_AUTOMATION.md) - Testing documentation
- [SUMMARY_REDIS_VERSION_AUTOMATION.md](SUMMARY_REDIS_VERSION_AUTOMATION.md) - Implementation summary
- [scripts/README.md](../scripts/README.md) - Scripts documentation

### [CHANGELOG_REDIS_URL.md](CHANGELOG_REDIS_URL.md)
**Date:** 2026-01-06

Centralization of Redis Enterprise download URL configuration.

**Key Changes:**
- Added `REDIS_ENTERPRISE_URL` to `.env.sample`
- Updated deployment scripts to validate and export the URL
- Removed hardcoded default values from all `variables.tf` files
- Updated documentation and verification scripts

### [CHANGELOG_DEPLOYMENT_SHORTCUTS.md](CHANGELOG_DEPLOYMENT_SHORTCUTS.md)
**Date:** 2026-01-06

Implementation of quick deployment shortcuts for all configurations.

**Key Changes:**
- Created 18 deployment shortcut scripts (AWS, GCP, Azure, GKE, ACRE)
- Implemented interactive menu (`deploy.sh`)
- Added comprehensive documentation
- Enabled deployment from project root without navigation

### [CHANGELOG_TAGGING.md](CHANGELOG_TAGGING.md)
**Date:** 2026-01-06

Implementation of automated tagging and credentials management system.

**Key Changes:**
- Created `.env.sample` template for environment configuration
- Added `owner` and `skip_deletion` variables to all configurations
- Updated all modules to support resource tagging
- Created generic deployment scripts with credential management
- Implemented verification script (`verify_setup.sh`)

## 🔗 Quick Links

- [Main README](../README.md) - Project overview and quick start guide
- [Verification Script](../scripts/verify_setup.sh) - Setup verification tool
- [Deployment Menu](../deploy.sh) - Interactive deployment menu

## 📖 How to Use This Documentation

1. **Getting Started**: Start with the [main README](../README.md)
2. **Setup**: Follow [TAGGING_AND_CREDENTIALS.md](TAGGING_AND_CREDENTIALS.md)
3. **Deployment**: Use [DEPLOYMENT_SHORTCUTS.md](DEPLOYMENT_SHORTCUTS.md) or [SHORTCUTS_REFERENCE.md](SHORTCUTS_REFERENCE.md)
4. **Technical Details**: Refer to [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)
5. **Change History**: Check the relevant CHANGELOG files

## 🎯 Documentation Maintenance

This directory is maintained to keep the project root clean while providing comprehensive documentation for users and contributors.

**Guidelines:**
- User-facing documentation goes in the main README.md
- Detailed guides and references go in this directory
- Changelogs document all significant changes
- Technical implementation details are preserved for reference

## 📞 Support

For questions or issues:
1. Check the relevant documentation file
2. Review the changelogs for recent changes
3. Run `./scripts/verify_setup.sh` to diagnose setup issues
4. Consult the [main README](../README.md) for general guidance

