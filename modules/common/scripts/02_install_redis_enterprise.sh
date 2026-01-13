#!/usr/bin/env bash
#
# 02_install_redis_enterprise.sh - Download and install Redis Enterprise
#
# This script downloads and installs Redis Enterprise:
# - Downloads the Redis Enterprise tarball
# - Extracts and runs the installer
# - Waits for services to be ready
# - Optionally prepares flash storage
#
# Usage: Called automatically by cloud-init/user-data
#
# Variables (passed via templatefile or environment):
#   SSH_USER      - The SSH user for the instance
#   REDIS_DISTRO  - URL to download Redis Enterprise tarball
#   FLASH_ENABLED - Whether to prepare flash storage (true/false)
#
set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================
SSH_USER="${SSH_USER:-ubuntu}"
REDIS_DISTRO="${REDIS_DISTRO:-}"
FLASH_ENABLED="${FLASH_ENABLED:-false}"
LOG_FILE="/home/${SSH_USER}/install_redis.log"
INSTALL_DIR="/home/${SSH_USER}/install"

log() {
    echo "$(date -Is) - $1" | tee -a "$LOG_FILE"
}

# ============================================================================
# Validation
# ============================================================================
if [ -z "$REDIS_DISTRO" ]; then
    log "ERROR: REDIS_DISTRO environment variable is not set"
    exit 1
fi

log "=== Starting Redis Enterprise installation ==="

# ============================================================================
# Download Redis Enterprise
# ============================================================================
log "Downloading Redis Enterprise from: ${REDIS_DISTRO}"
cd "$INSTALL_DIR"

if ! wget -q "${REDIS_DISTRO}" -P "$INSTALL_DIR"; then
    log "ERROR: Failed to download Redis Enterprise"
    exit 1
fi

# ============================================================================
# Extract Redis Enterprise
# ============================================================================
log "Extracting Redis Enterprise..."
tar xf "$INSTALL_DIR"/redislabs*.tar -C "$INSTALL_DIR"

# ============================================================================
# Install Redis Enterprise
# ============================================================================
log "Installing Redis Enterprise (silent installation)..."
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Log file for installer output (keeps Terraform output clean)
RS_INSTALL_LOG="/home/${SSH_USER}/install_rs.log"

# Run the installer with -y for non-interactive mode
log "Running install.sh (see ${RS_INSTALL_LOG} for details)..."
if ! sudo -E "$INSTALL_DIR/install.sh" -y >> "$RS_INSTALL_LOG" 2>&1; then
    log "ERROR: Redis Enterprise installation failed. Check ${RS_INSTALL_LOG} for details."
    # Show last 20 lines of log for debugging
    tail -20 "$RS_INSTALL_LOG" | while read line; do log "  $line"; done
    exit 1
fi

# Verify rladmin exists (critical check)
if [ ! -x /opt/redislabs/bin/rladmin ]; then
    log "ERROR: rladmin not found after installation. Installation may have failed."
    exit 1
fi

# Add user to redislabs group
sudo adduser "${SSH_USER}" redislabs 2>/dev/null || true

log "Redis Enterprise installation complete"

# ============================================================================
# Wait for Redis Enterprise services to be ready
# ============================================================================
log "Waiting for Redis Enterprise services to start..."

MAX_WAIT=120
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    if sudo /opt/redislabs/bin/supervisorctl status 2>/dev/null | grep -q "RUNNING"; then
        log "Redis Enterprise services are running"
        break
    fi
    log "Waiting for services... ($WAITED/$MAX_WAIT seconds)"
    sleep 5
    WAITED=$((WAITED + 5))
done

if [ $WAITED -ge $MAX_WAIT ]; then
    log "WARNING: Timeout waiting for services, continuing anyway..."
fi

# Additional wait to ensure all services are fully initialized
sleep 10

# ============================================================================
# Prepare Flash Storage (if enabled)
# ============================================================================
# Redis on Flash requires local NVMe storage (i3/i4i instances on AWS,
# Local SSDs on GCP, Lsv3 on Azure). EBS/network storage is NOT supported.
# See: https://redis.io/docs/latest/operate/rs/databases/flash/
if [ "$FLASH_ENABLED" = "true" ]; then
    log "Setting up flash storage..."

    # Run Redis prepare_flash.sh to detect and configure local NVMe disks
    if [ -x /opt/redislabs/sbin/prepare_flash.sh ]; then
        log "Running Redis prepare_flash.sh..."
        if sudo /opt/redislabs/sbin/prepare_flash.sh -y 2>&1 | tee -a "$LOG_FILE"; then
            log "Flash storage prepared successfully"
        else
            log "WARNING: Flash storage preparation failed. Make sure you are using instances with local NVMe (i3/i4i on AWS, Local SSDs on GCP, Lsv3 on Azure)"
        fi
    else
        log "WARNING: prepare_flash.sh not found, skipping flash preparation"
    fi
fi

# ============================================================================
# Cleanup
# ============================================================================
log "Cleaning up installation files..."
rm -f "$INSTALL_DIR"/redislabs*.tar

log "=== Redis Enterprise installation complete ==="

