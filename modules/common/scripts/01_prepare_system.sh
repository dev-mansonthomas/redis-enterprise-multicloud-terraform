#!/usr/bin/env bash
#
# 01_prepare_system.sh - System preparation for Redis Enterprise
#
# This script prepares the system for Redis Enterprise installation:
# - Updates packages and installs utilities
# - Configures DNS (disables systemd-resolved stub listener)
# - Configures sysctl for Redis Enterprise
# - Disables swap (optional, based on cloud provider)
#
# Usage: Called automatically by cloud-init/user-data
#
# Variables (passed via templatefile or environment):
#   SSH_USER - The SSH user for the instance (e.g., ubuntu)
#
set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================
SSH_USER="${SSH_USER:-ubuntu}"
LOG_FILE="/home/${SSH_USER}/install_redis.log"

log() {
    echo "$(date -Is) - $1" | tee -a "$LOG_FILE"
}

# ============================================================================
# Detect user if not set
# ============================================================================
if [ ! -d "/home/${SSH_USER}" ]; then
    if [ -d /home/ubuntu ]; then
        SSH_USER=ubuntu
    elif [ -d /home/outscale ]; then
        SSH_USER=outscale
    else
        echo "Error: No recognized user home directory found" >&2
        exit 1
    fi
    LOG_FILE="/home/${SSH_USER}/install_redis.log"
fi

log "=== Starting system preparation ==="
log "Detected user: ${SSH_USER}"

# ============================================================================
# Configure non-interactive mode for apt
# ============================================================================
log "Configuring non-interactive apt mode..."
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Disable needrestart interactive prompts (Ubuntu 22.04+)
# This prevents "Scanning processes..." output during apt operations
if [ -d /etc/needrestart/conf.d ]; then
    cat > /etc/needrestart/conf.d/99-disable-interactive.conf << 'EOF'
# Disable interactive mode - auto-restart services without prompting
$nrconf{restart} = 'a';
# Disable kernel hints
$nrconf{kernelhints} = 0;
EOF
fi

# Log file for apt operations (keeps Terraform output clean)
APT_LOG="/home/${SSH_USER}/apt_install.log"

# Helper function to run apt commands with error handling
run_apt() {
    local cmd="$1"
    if ! eval "$cmd" >> "$APT_LOG" 2>&1; then
        log "ERROR: apt command failed. Last 100 lines of log:"
        tail -100 "$APT_LOG" | while IFS= read -r line; do log "  $line"; done
        return 1
    fi
}

# ============================================================================
# Wait for cloud-init and other apt processes to finish
# ============================================================================
log "Waiting for cloud-init to end."
if command -v cloud-init >/dev/null 2>&1; then
  cloud-init status --wait || true
fi

# ============================================================================
# Update system packages
# ============================================================================
log "Updating system packages (see ${APT_LOG} for details)..."
run_apt "apt-get update -y"
run_apt "apt-get upgrade -y"

# Wait for upgrade to complete (avoid dpkg lock issues)
sleep 5

# ============================================================================
# Install utilities
# ============================================================================
log "Installing utilities..."
run_apt "apt-get install -y vim iputils-ping curl jq netcat-openbsd dnsutils tzdata"

# ============================================================================
# Configure timezone
# ============================================================================
log "Configuring timezone..."
export TZ="UTC"
ln -fs /usr/share/zoneinfo/UTC /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata

# ============================================================================
# Configure DNS - Disable systemd-resolved stub listener
# This is required because Redis Enterprise runs its own DNS server (mdns)
# ============================================================================
log "Configuring DNS (disabling systemd-resolved stub listener)..."
if ! grep -q "DNSStubListener=no" /etc/systemd/resolved.conf; then
    echo 'DNSStubListener=no' | tee -a /etc/systemd/resolved.conf
fi

if [ -f /etc/resolv.conf ] && [ ! -L /etc/resolv.conf ]; then
    mv /etc/resolv.conf /etc/resolv.conf.orig
    ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
fi
systemctl restart systemd-resolved

# ============================================================================
# Configure sysctl for Redis Enterprise
# ============================================================================
log "Configuring sysctl parameters..."

# Expand ephemeral port range to avoid collisions with Redis ports
if ! grep -q "net.ipv4.ip_local_port_range" /etc/sysctl.conf; then
    echo 'net.ipv4.ip_local_port_range = 30000 65535' | tee -a /etc/sysctl.conf
fi

sysctl -w net.ipv4.ip_local_port_range="30000 65535"

# ============================================================================
# Create /etc/rc.local if missing (Ubuntu 22.04+ compatibility)
# Redis Enterprise installer may look for this file
# ============================================================================
if [ ! -f /etc/rc.local ]; then
    log "Creating /etc/rc.local for Ubuntu 22.04+ compatibility..."
    cat > /etc/rc.local << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x /etc/rc.local
fi

# ============================================================================
# Create install directory
# ============================================================================
log "Creating install directory..."
mkdir -p "/home/${SSH_USER}/install"
chown "${SSH_USER}:${SSH_USER}" "/home/${SSH_USER}/install"

log "=== System preparation complete ==="

