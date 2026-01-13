#!/usr/bin/env bash
#
# install_redis_enterprise_full.sh - Complete Redis Enterprise installation
#
# This is the main orchestration script that runs all installation steps.
# It's designed to be used as user-data/cloud-init script.
#
# Usage: This script is typically rendered via Terraform templatefile()
#
# Required Variables:
#   SSH_USER       - The SSH user for the instance (e.g., ubuntu)
#   REDIS_DISTRO   - URL to download Redis Enterprise tarball
#   NODE_ID        - Node ID (1 for master, 2+ for workers)
#   CLUSTER_DNS    - DNS name for the cluster
#   ADMIN_USER     - Admin username for the cluster
#   ADMIN_PASSWORD - Admin password for the cluster
#   ZONE           - Availability zone / rack ID
#
# Optional Variables:
#   FLASH_ENABLED  - Whether to prepare flash storage (default: false)
#   EXTERNAL_ADDR  - External IP (default: auto-detect via ifconfig.me)
#   PRIVATE_CONF   - If true, don't set external_addr (default: false)
#   MASTER_IP      - IP of master node (required for nodes 2+)
#
set -euo pipefail

# ============================================================================
# Configuration from environment (set by Terraform templatefile)
# ============================================================================
SSH_USER="${SSH_USER:-ubuntu}"
REDIS_DISTRO="${REDIS_DISTRO:-}"
NODE_ID="${NODE_ID:-1}"
CLUSTER_DNS="${CLUSTER_DNS:-}"
ADMIN_USER="${ADMIN_USER:-}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
ZONE="${ZONE:-}"
FLASH_ENABLED="${FLASH_ENABLED:-false}"
EXTERNAL_ADDR="${EXTERNAL_ADDR:-}"
PRIVATE_CONF="${PRIVATE_CONF:-false}"
MASTER_IP="${MASTER_IP:-}"

LOG_FILE="/home/${SSH_USER}/install_redis.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Logging
# ============================================================================
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "$(date -Is) - $1"
}

log "========================================================"
log "= Redis Enterprise Installation - Node ${NODE_ID}"
log "========================================================"

# ============================================================================
# Step 1: Prepare System
# ============================================================================
log ">>> Step 1: Preparing system..."
export SSH_USER
source "${SCRIPT_DIR}/01_prepare_system.sh"

# ============================================================================
# Step 2: Install Redis Enterprise
# ============================================================================
log ">>> Step 2: Installing Redis Enterprise..."
export SSH_USER REDIS_DISTRO FLASH_ENABLED
source "${SCRIPT_DIR}/02_install_redis_enterprise.sh"

# ============================================================================
# Step 3: Create or Join Cluster
# ============================================================================
log ">>> Step 3: Configuring cluster..."

# Determine external address
if [ "$PRIVATE_CONF" = "true" ]; then
    EXTERNAL_ADDR="none"
elif [ -z "$EXTERNAL_ADDR" ]; then
    log "Auto-detecting external IP..."
    EXTERNAL_ADDR=$(curl -s ifconfig.me/ip || echo "none")
    log "Detected external IP: ${EXTERNAL_ADDR}"
fi

# Determine mode
if [ "$NODE_ID" -eq 1 ]; then
    MODE="init"
else
    MODE="join"
    if [ -z "$MASTER_IP" ]; then
        log "ERROR: MASTER_IP is required for nodes joining the cluster"
        exit 1
    fi
fi

"${SCRIPT_DIR}/03_create_or_join_cluster.sh" \
    "$CLUSTER_DNS" \
    "$ADMIN_USER" \
    "$ADMIN_PASSWORD" \
    "$MODE" \
    "$EXTERNAL_ADDR" \
    "$ZONE" \
    "$NODE_ID" \
    "$MASTER_IP"

# ============================================================================
# Store node info for later use
# ============================================================================
echo "$NODE_ID" > "/home/${SSH_USER}/node_index.terraform"
chown "${SSH_USER}:${SSH_USER}" "/home/${SSH_USER}/node_index.terraform"

log "========================================================"
log "= Redis Enterprise Installation Complete - Node ${NODE_ID}"
log "========================================================"

