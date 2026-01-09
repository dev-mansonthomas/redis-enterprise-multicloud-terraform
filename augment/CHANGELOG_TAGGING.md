# Changelog: Tagging and Credentials Management

## Date: 2025-12-22

## Summary

Implemented a comprehensive tagging and credentials management system across the entire project to comply with management requirements.

## What Changed

### 🏷️ Tagging System

All cloud resources are now automatically tagged with:
- **owner**: Your name in format `firstname_lastname` (e.g., `steve_jenner`)
- **skip_deletion**: Set to `yes` for resources that should not be deleted

### 🔐 Credentials Management

Credentials are now managed through a `.env` file instead of being hardcoded or passed manually:
- AWS credentials (access key and secret key)
- GCP credentials (JSON file and project ID)
- Azure credentials (subscription ID, tenant ID, client ID, client secret)

### 📝 New Files

1. **`.env.sample`** - Template for environment configuration
2. **`TAGGING_AND_CREDENTIALS.md`** - Complete user documentation
3. **`IMPLEMENTATION_SUMMARY.md`** - Technical implementation details
4. **`CHANGELOG_TAGGING.md`** - This file
5. **`scripts/tofu_apply_template.sh`** - Generic apply script template
6. **`scripts/tofu_destroy_template.sh`** - Generic destroy script template
7. **`scripts/verify_setup.sh`** - Verification script to check setup

### 🔄 Modified Files

#### Configuration Files (28 total)
All `.tf.json` files now include:
- A `locals` block with `common_tags` or `common_labels`
- Updated module calls to pass tags

#### Variable Definitions (18 total)
All `variables.tf` files now include:
- `owner` variable
- `skip_deletion` variable

#### Deployment Scripts (36 total)
All configuration directories now have:
- `tofu_apply.sh` - Automated deployment script
- `tofu_destroy.sh` - Automated destruction script

#### Documentation
- **`README.adoc`** - Updated with Quick Start section for tagging and credentials
- **`.gitignore`** - Added `.env` to prevent credential leakage

## Migration Guide

### For Existing Users

If you were using the old manual credential passing method:

#### Before (Old Method)
```bash
source ~/.cred/aws.sh

tofu apply \
  -var="deployment_name=flash-test" \
  -var="aws_access_key=$KEY" \
  -var="aws_secret_key=$SEC" \
  -auto-approve
```

#### After (New Method)
```bash
# 1. Create .env file (one time)
cp .env.sample .env
vim .env  # Set OWNER and credentials

# 2. Deploy (every time)
./tofu_apply.sh
```

### Setup Steps

1. **Create your `.env` file**
   ```bash
   cp .env.sample .env
   ```

2. **Configure your credentials and owner tag**
   ```bash
   vim .env
   ```
   
   Minimum required:
   ```bash
   OWNER=firstname_lastname
   
   # For AWS
   AWS_CREDENTIALS_FILE=/path/to/aws/credentials.sh
   # OR
   AWS_ACCESS_KEY=your-key
   AWS_SECRET_KEY=your-secret
   
   # For GCP
   GCP_CREDENTIALS_FILE=/path/to/gcp/credentials.json
   GCP_PROJECT_ID=your-project-id
   
   # For Azure
   AZURE_SUBSCRIPTION_ID=your-subscription-id
   AZURE_TENANT_ID=your-tenant-id
   AZURE_CLIENT_ID=your-client-id
   AZURE_CLIENT_SECRET=your-client-secret
   ```

3. **Verify your setup**
   ```bash
   ./scripts/verify_setup.sh
   ```

4. **Deploy as usual**
   ```bash
   cd main/AWS/Mono-Region/Rack_Aware_Cluster
   ./tofu_apply.sh
   ```

## Benefits

✅ **Compliance**: All resources are properly tagged with owner and skip_deletion tags
✅ **Security**: Credentials are no longer hardcoded or committed to git
✅ **Consistency**: Same approach across AWS, GCP, and Azure
✅ **Simplicity**: One `.env` file for all configurations
✅ **Automation**: Scripts automatically detect cloud provider and load credentials
✅ **Maintainability**: Easy to update credentials or add new tags

## Breaking Changes

⚠️ **Important**: The old manual credential passing method still works, but is deprecated.

If you have custom scripts that call `tofu apply` or `tofu destroy` directly, you need to:
1. Add `-var="owner=firstname_lastname"` to your commands
2. Add `-var="skip_deletion=yes"` to your commands

Or better yet, migrate to using the new `tofu_apply.sh` and `tofu_destroy.sh` scripts.

## Verification

To verify that the tagging system is working:

1. Deploy a test resource
2. Check the cloud provider console
3. Verify that resources have the `owner` and `skip_deletion` tags

Example for AWS:
```bash
aws ec2 describe-instances --filters "Name=tag:owner,Values=firstname_lastname"
```

## Support

For questions or issues:
- See `TAGGING_AND_CREDENTIALS.md` for detailed documentation
- See `IMPLEMENTATION_SUMMARY.md` for technical details
- Run `./scripts/verify_setup.sh` to check your setup

## Future Enhancements

Potential improvements for future versions:
- Integration with secret management systems (AWS Secrets Manager, etc.)
- Support for additional tags (environment, cost_center, project)
- CI/CD pipeline integration
- Automated tag validation
- Multi-environment support (dev, staging, prod)

