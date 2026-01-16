#!/usr/bin/env bash
#
# 03_create_or_join_cluster.sh - Create or join a Redis Enterprise cluster
#
# This script creates a new Redis Enterprise cluster or joins an existing one.
# Inspired by the Packer build scripts for better reliability.
#
# Usage: 
#   ./03_create_or_join_cluster.sh <cluster_dns> <admin_user> <admin_password> \
#                                   <mode> <external_addr> <zone> <node_id> [master_ip]
#
# Arguments:
#   cluster_dns    - DNS name for the cluster (e.g., cluster.redis.local)
#   admin_user     - Admin username for the cluster
#   admin_password - Admin password for the cluster
#   mode           - 'init' to create new cluster, 'join' to join existing
#   external_addr  - External IP address of this node (or 'none' for private config)
#   zone           - Availability zone / rack ID for rack awareness
#   node_id        - Node ID (1 for master, 2+ for workers)
#   master_ip      - (required for 'join' mode) IP of the master node
#
set -euo pipefail

# ============================================================================
# Parse arguments
# ============================================================================
CLUSTER_DNS="${1:-}"
ADMIN_USER="${2:-}"
ADMIN_PASSWORD="${3:-}"
MODE="${4:-}"
EXTERNAL_ADDR="${5:-}"
ZONE="${6:-}"
NODE_ID="${7:-}"
MASTER_IP="${8:-}"

SSH_USER="${SSH_USER:-ubuntu}"
LOG_FILE="/home/${SSH_USER}/install_redis.log"

log() {
    echo "$(date -Is) - $1" | tee -a "$LOG_FILE"
}

# ============================================================================
# Validate required parameters
# ============================================================================
for var_name in CLUSTER_DNS ADMIN_USER ADMIN_PASSWORD MODE EXTERNAL_ADDR ZONE NODE_ID; do
    if [ -z "${!var_name}" ]; then
        log "ERROR: Missing required parameter: $var_name"
        echo "Usage: $0 <cluster_dns> <admin_user> <admin_password> <mode> <external_addr> <zone> <node_id> [master_ip]"
        exit 1
    fi
done

if [ "$MODE" = "join" ] && [ -z "$MASTER_IP" ]; then
    log "ERROR: Missing required parameter: master_ip for join mode"
    exit 1
fi

# ============================================================================
# Verify Redis Enterprise is installed (critical check)
# ============================================================================
if [ ! -x /opt/redislabs/bin/rladmin ]; then
    log "ERROR: rladmin not found at /opt/redislabs/bin/rladmin"
    log "ERROR: Redis Enterprise installation may have failed. Cannot proceed with cluster configuration."
    exit 1
fi

log "=== Starting cluster configuration ==="
log "Mode: $MODE, Node ID: $NODE_ID, Zone: $ZONE"

# ============================================================================
# Update /etc/hosts with internal IP
# ============================================================================
INTERNAL_IP=$(ip -4 -o addr show | awk '!/127\.0\.0\.1/ && /inet/ {print $4}' | cut -d/ -f1 | head -1)
HOSTNAME_FMT="redis-node-${NODE_ID}"

log "Updating /etc/hosts with ${INTERNAL_IP} ${HOSTNAME_FMT}"
echo "${INTERNAL_IP} ${HOSTNAME_FMT}" >> /etc/hosts

# ============================================================================
# Build rladmin command
# ============================================================================
build_cluster_command() {
    local cmd="/opt/redislabs/bin/rladmin cluster"

    if [ "$MODE" = "init" ]; then
        cmd="$cmd create name ${CLUSTER_DNS}"
        cmd="$cmd username ${ADMIN_USER} password '${ADMIN_PASSWORD}'"
        # flash_enabled is only valid for cluster create, not join
        if [ "${FLASH_ENABLED:-false}" = "true" ]; then
            cmd="$cmd flash_enabled"
        fi
        cmd="$cmd rack_aware rack_id '${ZONE}'"
    else
        cmd="$cmd join nodes ${MASTER_IP}"
        cmd="$cmd username ${ADMIN_USER} password '${ADMIN_PASSWORD}'"
        cmd="$cmd rack_id '${ZONE}'"
    fi

    # Add external address if not 'none' (for public configurations)
    if [ "$EXTERNAL_ADDR" != "none" ]; then
        cmd="$cmd external_addr ${EXTERNAL_ADDR}"
    fi

    echo "$cmd"
}

# ============================================================================
# Create cluster (for node 1)
# ============================================================================
create_cluster() {
    log "Creating new cluster: ${CLUSTER_DNS}"
    
    local cmd
    cmd=$(build_cluster_command)
    log "Executing: ${cmd//${ADMIN_PASSWORD}/***}"
    
    if sudo bash -c "$cmd" 2>&1 | tee -a "$LOG_FILE"; then
        log "Cluster created successfully"
        return 0
    else
        log "ERROR: Cluster creation failed"
        return 1
    fi
}

# ============================================================================
# Join cluster (for nodes 2+)
# ============================================================================
join_cluster() {
    local max_retries=10
    local retry_delay=30
    
    log "Joining cluster at ${MASTER_IP}"
    
    local cmd
    cmd=$(build_cluster_command)
    log "Executing: ${cmd//${ADMIN_PASSWORD}/***}"
    
    for i in $(seq 1 $max_retries); do
        log "Join attempt $i/$max_retries..."
        
        if sudo bash -c "$cmd" 2>&1 | tee -a "$LOG_FILE"; then
            log "Successfully joined cluster"
            return 0
        fi
        
        log "Join failed, master may not be ready. Retrying in ${retry_delay}s..."
        sleep $retry_delay
    done
    
    log "ERROR: Failed to join cluster after $max_retries attempts"
    return 1
}

# ============================================================================
# Main execution
# ============================================================================
if [ "$MODE" = "init" ]; then
    create_cluster
elif [ "$MODE" = "join" ]; then
    join_cluster
else
    log "ERROR: Invalid mode '$MODE'. Use 'init' or 'join'"
    exit 1
fi

log "=== Cluster configuration complete ==="

