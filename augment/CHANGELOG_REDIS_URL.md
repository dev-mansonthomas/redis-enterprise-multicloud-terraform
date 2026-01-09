# Changelog - Centralisation de l'URL Redis Enterprise

## Date
2026-01-06

## Résumé
Centralisation de l'URL de téléchargement de Redis Enterprise dans le fichier `.env` pour faciliter la maintenance et éviter les incohérences entre les différentes configurations.

## Changements effectués

### 1. Configuration centralisée (`.env`)

#### Fichiers modifiés :
- `.env.sample` - Ajout de la variable `REDIS_ENTERPRISE_URL`

#### Nouvelle variable :
```bash
REDIS_ENTERPRISE_URL=https://s3.amazonaws.com/redis-enterprise-software-downloads/8.0.6/redislabs-8.0.6-54-jammy-amd64.tar
```

**Important** : Cette variable est maintenant **OBLIGATOIRE**. Le déploiement échouera si elle n'est pas définie.

### 2. Scripts de déploiement

#### Fichiers modifiés :
- `scripts/tofu_apply_template.sh`
- `scripts/tofu_destroy_template.sh`

#### Changements :
- ✅ Ajout de la validation de `REDIS_ENTERPRISE_URL` (obligatoire)
- ✅ Passage automatique de la variable à Terraform via `-var="rs_release=$REDIS_ENTERPRISE_URL"`
- ✅ Affichage de l'URL Redis Enterprise dans le résumé de déploiement
- ✅ Message d'erreur explicite si la variable n'est pas définie

### 3. Variables Terraform (12 fichiers)

#### Fichiers modifiés :
**AWS** (4 fichiers) :
- `main/AWS/Mono-Region/Basic_Cluster/variables.tf`
- `main/AWS/Mono-Region/Rack_Aware_Cluster/variables.tf`
- `main/AWS/Cross-Region/Basic_Clusters/variables.tf`
- `main/AWS/Cross-Region/Rack_Aware_Clusters/variables.tf`

**GCP** (4 fichiers) :
- `main/GCP/Mono-Region/Basic_Cluster/variables.tf`
- `main/GCP/Mono-Region/Rack_Aware_Cluster/variables.tf`
- `main/GCP/Cross-Region/Basic_Clusters/variables.tf`
- `main/GCP/Cross-Region/Rack_Aware_Clusters/variables.tf`

**Azure** (4 fichiers) :
- `main/Azure/Mono-Region/Basic_Cluster/variables.tf`
- `main/Azure/Mono-Region/Rack_Aware_Cluster/variables.tf`
- `main/Azure/Cross-Region/Basic_Clusters/variables.tf`
- `main/Azure/Cross-Region/Rack_Aware_Clusters/variables.tf`

#### Changements :
**AVANT** :
```hcl
variable "rs_release" {
  default = "https://s3.amazonaws.com/redis-enterprise-software-downloads/6.4.2/redislabs-6.4.2-81-focal-amd64.tar"
}
```

**APRÈS** :
```hcl
variable "rs_release" {
  description = "Redis Enterprise download URL (set via REDIS_ENTERPRISE_URL in .env)"
  type        = string
}
```

**Raison** : Suppression des valeurs par défaut pour éviter la maintenance de 12 fichiers différents.

### 4. Script de vérification

#### Fichier modifié :
- `scripts/verify_setup.sh`

#### Changements :
- ✅ Ajout de la vérification de `REDIS_ENTERPRISE_URL` dans `.env`
- ✅ Message d'erreur si la variable n'est pas définie

### 5. Documentation

#### Fichiers modifiés :
- `TAGGING_AND_CREDENTIALS.md`
- `QUICK_START.md`

#### Changements :
- ✅ Ajout de la documentation pour `REDIS_ENTERPRISE_URL`
- ✅ Exemples d'utilisation mis à jour

### 6. Scripts de déploiement (18 répertoires)

Tous les scripts `tofu_apply.sh` et `tofu_destroy.sh` ont été mis à jour dans :
- 4 configurations AWS
- 4 configurations GCP
- 4 configurations GCP GKE
- 4 configurations Azure
- 2 configurations Azure ACRE

## Migration

### Pour les utilisateurs existants :

1. **Mettre à jour votre `.env`** :
   ```bash
   # Ajouter cette ligne dans votre .env
   REDIS_ENTERPRISE_URL=https://s3.amazonaws.com/redis-enterprise-software-downloads/8.0.6/redislabs-8.0.6-54-jammy-amd64.tar
   ```

2. **Vérifier la configuration** :
   ```bash
   ./scripts/verify_setup.sh
   ```

3. **Déployer normalement** :
   ```bash
   cd main/AWS/Mono-Region/Rack_Aware_Cluster
   ./tofu_apply.sh
   ```

### Versions disponibles

Pour obtenir la dernière version de Redis Enterprise :
- Site officiel : https://redis.io/downloads/
- Format de l'URL : `https://s3.amazonaws.com/redis-enterprise-software-downloads/VERSION/redislabs-VERSION-BUILD-DISTRO-ARCH.tar`

Exemples :
- Version 8.0.6 (jammy/Ubuntu 22.04) : `https://s3.amazonaws.com/redis-enterprise-software-downloads/8.0.6/redislabs-8.0.6-54-jammy-amd64.tar`
- Version 7.22.0 (jammy/Ubuntu 22.04) : `https://s3.amazonaws.com/redis-enterprise-software-downloads/7.22.0/redislabs-7.22.0-216-jammy-amd64.tar`
- Version 6.4.2 (focal/Ubuntu 20.04) : `https://s3.amazonaws.com/redis-enterprise-software-downloads/6.4.2/redislabs-6.4.2-81-focal-amd64.tar`

## Avantages

✅ **Centralisation** : Une seule URL à maintenir dans `.env`
✅ **Cohérence** : Toutes les configurations utilisent la même version
✅ **Flexibilité** : Changement de version en une seule ligne
✅ **Validation** : Erreur explicite si l'URL n'est pas définie
✅ **Documentation** : URL visible dans le résumé de déploiement

## Breaking Changes

⚠️ **ATTENTION** : Cette modification introduit un changement incompatible avec les versions précédentes.

- La variable `REDIS_ENTERPRISE_URL` est maintenant **OBLIGATOIRE** dans `.env`
- Le déploiement échouera avec un message d'erreur clair si elle n'est pas définie
- Les valeurs par défaut dans les fichiers `variables.tf` ont été supprimées

## Rollback

Si vous devez revenir en arrière, vous pouvez :
1. Restaurer les valeurs par défaut dans les 12 fichiers `variables.tf`
2. Supprimer la validation de `REDIS_ENTERPRISE_URL` dans les scripts

Cependant, il est recommandé de simplement ajouter `REDIS_ENTERPRISE_URL` dans votre `.env`.

