# Changelog - Scripts de Raccourci de Déploiement

## Date
2026-01-06

## Résumé
Ajout de scripts de raccourci à la racine du projet pour faciliter le déploiement sans avoir à naviguer dans les dossiers.

## Motivation

**Avant** : Pour déployer une configuration, il fallait naviguer dans les dossiers :
```bash
cd main/AWS/Mono-Region/Rack_Aware_Cluster
./tofu_apply.sh
```

**Après** : Déploiement direct depuis la racine du projet :
```bash
./aws_mono_region_rack_aware.sh
```

Ou encore plus simple avec le menu interactif :
```bash
./deploy.sh
```

## Nouveaux Fichiers Créés

### 1. Script Menu Interactif

**Fichier** : `deploy.sh`

Menu interactif permettant de choisir parmi les 18 configurations disponibles :
- AWS (4 configurations)
- GCP (4 configurations)
- GCP GKE (4 configurations)
- Azure (4 configurations)
- Azure ACRE (2 configurations)

### 2. Scripts de Raccourci AWS (4 fichiers)

- `aws_mono_region_basic.sh` → `main/AWS/Mono-Region/Basic_Cluster`
- `aws_mono_region_rack_aware.sh` → `main/AWS/Mono-Region/Rack_Aware_Cluster`
- `aws_cross_region_basic.sh` → `main/AWS/Cross-Region/Basic_Clusters`
- `aws_cross_region_rack_aware.sh` → `main/AWS/Cross-Region/Rack_Aware_Clusters`

### 3. Scripts de Raccourci GCP (4 fichiers)

- `gcp_mono_region_basic.sh` → `main/GCP/Mono-Region/Basic_Cluster`
- `gcp_mono_region_rack_aware.sh` → `main/GCP/Mono-Region/Rack_Aware_Cluster`
- `gcp_cross_region_basic.sh` → `main/GCP/Cross-Region/Basic_Clusters`
- `gcp_cross_region_rack_aware.sh` → `main/GCP/Cross-Region/Rack_Aware_Clusters`

### 4. Scripts de Raccourci GCP GKE (4 fichiers)

- `gcp_gke_mono_region_basic.sh` → `main/GCP/GKE/Mono-Region/Basic_Cluster`
- `gcp_gke_mono_region_rack_aware.sh` → `main/GCP/GKE/Mono-Region/Rack_Aware_Cluster`
- `gcp_gke_cross_region_basic.sh` → `main/GCP/GKE/Cross-Region/Basic_Clusters`
- `gcp_gke_cross_region_rack_aware.sh` → `main/GCP/GKE/Cross-Region/Rack_Aware_Clusters`

### 5. Scripts de Raccourci Azure (4 fichiers)

- `azure_mono_region_basic.sh` → `main/Azure/Mono-Region/Basic_Cluster`
- `azure_mono_region_rack_aware.sh` → `main/Azure/Mono-Region/Rack_Aware_Cluster`
- `azure_cross_region_basic.sh` → `main/Azure/Cross-Region/Basic_Clusters`
- `azure_cross_region_rack_aware.sh` → `main/Azure/Cross-Region/Rack_Aware_Clusters`

### 6. Scripts de Raccourci Azure ACRE (2 fichiers)

- `azure_acre_enterprise.sh` → `main/Azure/ACRE/Enterprise`
- `azure_acre_oss.sh` → `main/Azure/ACRE/OSS`

### 7. Documentation

- `DEPLOYMENT_SHORTCUTS.md` - Documentation complète des scripts de raccourci
- `QUICK_START.md` - Mise à jour avec les nouvelles options de déploiement

## Fonctionnement

Chaque script de raccourci :
1. ✅ Affiche le nom de la configuration
2. ✅ Vérifie que le répertoire de configuration existe
3. ✅ Navigue vers le répertoire de configuration
4. ✅ Exécute le script `tofu_apply.sh` dans ce répertoire

## Utilisation

### Option 1 : Menu Interactif (Recommandé)

```bash
./deploy.sh
```

Affiche un menu numéroté avec toutes les configurations. Entrez simplement le numéro correspondant.

### Option 2 : Scripts Directs

```bash
# AWS
./aws_mono_region_rack_aware.sh

# GCP
./gcp_mono_region_basic.sh

# GCP GKE
./gcp_gke_cross_region_rack_aware.sh

# Azure
./azure_mono_region_rack_aware.sh

# Azure ACRE
./azure_acre_enterprise.sh
```

### Option 3 : Navigation Traditionnelle

```bash
cd main/AWS/Mono-Region/Rack_Aware_Cluster
./tofu_apply.sh
```

## Avantages

✅ **Gain de temps** - Plus besoin de naviguer dans les dossiers
✅ **Simplicité** - Noms de scripts clairs et cohérents
✅ **Menu interactif** - Facile à utiliser si vous oubliez le nom du script
✅ **Validation** - Les scripts vérifient que les répertoires existent
✅ **Compatibilité** - Les anciennes méthodes fonctionnent toujours

## Convention de Nommage

Tous les scripts suivent le pattern : `{provider}_{region_type}_{cluster_type}.sh`

- **provider** : `aws`, `gcp`, `azure`
- **region_type** : `mono_region`, `cross_region`, `gke`, `acre`
- **cluster_type** : `basic`, `rack_aware`, `enterprise`, `oss`

Exemples :
- `aws_mono_region_rack_aware.sh`
- `gcp_gke_cross_region_basic.sh`
- `azure_acre_enterprise.sh`

## Destruction d'Infrastructure

⚠️ **Note importante** : Il n'y a pas de scripts de raccourci pour la destruction.

Pour détruire l'infrastructure, vous devez naviguer vers le répertoire de configuration :

```bash
cd main/AWS/Mono-Region/Rack_Aware_Cluster
./tofu_destroy.sh
```

**Raison** : Ceci est intentionnel pour éviter les destructions accidentelles.

## Statistiques

- **1** script menu interactif (`deploy.sh`)
- **18** scripts de raccourci de déploiement
- **18** configurations disponibles
- **3** fournisseurs cloud (AWS, GCP, Azure)
- **2** fichiers de documentation mis à jour

## Compatibilité

✅ Tous les scripts sont compatibles avec bash
✅ Tous les scripts ont les permissions d'exécution (`chmod +x`)
✅ Les anciennes méthodes de déploiement fonctionnent toujours
✅ Aucun changement dans les scripts existants

## Voir Aussi

- [DEPLOYMENT_SHORTCUTS.md](DEPLOYMENT_SHORTCUTS.md) - Documentation détaillée
- [QUICK_START.md](QUICK_START.md) - Guide de démarrage rapide
- [TAGGING_AND_CREDENTIALS.md](TAGGING_AND_CREDENTIALS.md) - Configuration des credentials

