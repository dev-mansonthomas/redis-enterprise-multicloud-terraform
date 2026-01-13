# Redis Enterprise Installation Scripts

Scripts unifiés pour l'installation de Redis Enterprise sur AWS, GCP et Azure.

## 📁 Structure

```
modules/common/scripts/
├── 01_prepare_system.sh           # Préparation du système
├── 02_install_redis_enterprise.sh # Téléchargement et installation
├── 03_create_or_join_cluster.sh   # Création/jointure du cluster
├── install_redis_enterprise_full.sh # Script d'orchestration complet
└── README.md                       # Ce fichier
```

## 🔄 Utilisation

### Option 1: Script complet (recommandé)

```bash
export SSH_USER=ubuntu
export REDIS_DISTRO="https://..."
export NODE_ID=1
export CLUSTER_DNS="cluster.redis.local"
export ADMIN_USER="admin@redis.local"
export ADMIN_PASSWORD="your_password"
export ZONE="us-east-1a"
export FLASH_ENABLED=true
# Pour nodes 2+:
# export MASTER_IP="10.0.0.10"

./install_redis_enterprise_full.sh
```

### Option 2: Scripts individuels

```bash
# Étape 1: Préparation système
export SSH_USER=ubuntu
./01_prepare_system.sh

# Étape 2: Installation Redis Enterprise
export REDIS_DISTRO="https://..."
export FLASH_ENABLED=true
./02_install_redis_enterprise.sh

# Étape 3: Configuration cluster
./03_create_or_join_cluster.sh cluster.dns admin@redis.local password init 1.2.3.4 zone-a 1
```

## 📋 Variables

| Variable | Requis | Description |
|----------|--------|-------------|
| `SSH_USER` | ✅ | Utilisateur SSH (ubuntu, outscale) |
| `REDIS_DISTRO` | ✅ | URL du tarball Redis Enterprise |
| `NODE_ID` | ✅ | ID du nœud (1=master, 2+=worker) |
| `CLUSTER_DNS` | ✅ | Nom DNS du cluster |
| `ADMIN_USER` | ✅ | Utilisateur admin Redis |
| `ADMIN_PASSWORD` | ✅ | Mot de passe admin |
| `ZONE` | ✅ | Zone/rack pour rack awareness |
| `FLASH_ENABLED` | ❌ | Activer Redis on Flash (default: false) |
| `PRIVATE_CONF` | ❌ | Config privée sans external_addr (default: false) |
| `MASTER_IP` | ⚠️ | IP du master (requis pour nodes 2+) |

## 🔧 Intégration Terraform

Les scripts sont conçus pour être utilisés avec `templatefile()`:

```hcl
user_data = templatefile("${path.module}/../../common/scripts/install_redis_enterprise_full.sh", {
  SSH_USER       = var.ssh_user
  REDIS_DISTRO   = var.redis_distro
  NODE_ID        = count.index + 1
  CLUSTER_DNS    = var.cluster_dns
  ADMIN_USER     = var.redis_user
  ADMIN_PASSWORD = var.redis_password
  ZONE           = var.availability_zones[count.index % length(var.availability_zones)]
  FLASH_ENABLED  = var.flash_enabled
  PRIVATE_CONF   = var.private_conf
  MASTER_IP      = count.index == 0 ? "" : local.master_ip
})
```

## 📊 Logs

Tous les logs sont écrits dans:
- `/home/{SSH_USER}/install_redis.log` - Log principal
- `/home/{SSH_USER}/install_rs.log` - Log de l'installateur Redis
- `/var/log/redis-enterprise-init.log` - Log d'initialisation cluster

