# Quick Reference - Deployment Shortcuts

## 🚀 Quick Start

### Interactive Menu (Easiest)
```bash
./deploy.sh
```

## 📋 All Available Scripts

### AWS (4 scripts)
```bash
./aws_mono_region_basic.sh              # Single AZ
./aws_mono_region_rack_aware.sh         # Multi-AZ
./aws_cross_region_basic.sh             # Multi-region, single AZ
./aws_cross_region_rack_aware.sh        # Multi-region, multi-AZ
```

### GCP (4 scripts)
```bash
./gcp_mono_region_basic.sh              # Single zone
./gcp_mono_region_rack_aware.sh         # Multi-zone
./gcp_cross_region_basic.sh             # Multi-region, single zone
./gcp_cross_region_rack_aware.sh        # Multi-region, multi-zone
```

### GCP GKE - Kubernetes (4 scripts)
```bash
./gcp_gke_mono_region_basic.sh          # Single zone on K8s
./gcp_gke_mono_region_rack_aware.sh     # Multi-zone on K8s
./gcp_gke_cross_region_basic.sh         # Multi-region on K8s
./gcp_gke_cross_region_rack_aware.sh    # Multi-region, multi-zone on K8s
```

### Azure (4 scripts)
```bash
./azure_mono_region_basic.sh            # Single AZ
./azure_mono_region_rack_aware.sh       # Multi-AZ
./azure_cross_region_basic.sh           # Multi-region, single AZ
./azure_cross_region_rack_aware.sh      # Multi-region, multi-AZ
```

### Azure ACRE - Managed Service (2 scripts)
```bash
./azure_acre_enterprise.sh              # Azure Cache for Redis Enterprise
./azure_acre_oss.sh                     # Azure Cache for Redis OSS
```

## 🎯 Common Use Cases

### Deploy a production-ready AWS cluster
```bash
./aws_mono_region_rack_aware.sh
```

### Deploy a GCP Kubernetes cluster
```bash
./gcp_gke_mono_region_rack_aware.sh
```

### Deploy Azure managed Redis
```bash
./azure_acre_enterprise.sh
```

### Deploy a multi-region setup
```bash
./aws_cross_region_rack_aware.sh
# or
./gcp_cross_region_rack_aware.sh
# or
./azure_cross_region_rack_aware.sh
```

## 🗑️ Destroying Infrastructure

**Important**: There are no quick destroy scripts at the root level.

To destroy, navigate to the configuration directory:
```bash
cd main/AWS/Mono-Region/Rack_Aware_Cluster
./tofu_destroy.sh
```

## 📊 Script Naming Pattern

All scripts follow this pattern:
```
{provider}_{region_type}_{cluster_type}.sh
```

Where:
- **provider**: `aws`, `gcp`, `azure`
- **region_type**: `mono_region`, `cross_region`, `gke`, `acre`
- **cluster_type**: `basic`, `rack_aware`, `enterprise`, `oss`

## ✅ Prerequisites

Before using any script:
1. Create and configure `.env` file
2. Set `OWNER` variable
3. Set `REDIS_ENTERPRISE_URL` variable
4. Configure cloud provider credentials
5. Run `./scripts/verify_setup.sh`

## 📚 Documentation

- [DEPLOYMENT_SHORTCUTS.md](DEPLOYMENT_SHORTCUTS.md) - Detailed documentation
- [README.md](../README.md) - Quick start guide and full documentation
- [TAGGING_AND_CREDENTIALS.md](TAGGING_AND_CREDENTIALS.md) - Credentials setup

## 💡 Tips

- Use `./deploy.sh` if you can't remember the script name
- All scripts validate that directories exist before running
- Scripts automatically load credentials from `.env`
- All resources are tagged with `owner` and `skip_deletion`
- Use tab completion: `./aws_<TAB>` to see AWS options

## 🔍 Finding the Right Script

**Need high availability?** → Use `rack_aware` scripts
**Need disaster recovery?** → Use `cross_region` scripts
**Need Kubernetes?** → Use `gcp_gke_*` scripts
**Need managed service?** → Use `azure_acre_*` scripts
**Testing/Development?** → Use `basic` scripts

## 📞 Help

If you're unsure which configuration to use:
1. Run `./deploy.sh` to see all options
2. Check [README.md](../README.md) for descriptions
3. Review the configuration directories in `main/`

