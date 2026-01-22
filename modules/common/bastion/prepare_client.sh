#!/bin/bash
# =============================================================================
# Bastion/Client Node Preparation Script
# =============================================================================
# This script is used by all cloud providers (AWS, GCP, Azure) to install
# tools on the bastion node for Redis Enterprise POC and benchmarking.
#
# Template variables (replaced by Terraform):
#   ${ssh_user}              - Linux user for SSH access
#   ${cluster_dns}           - Redis Enterprise cluster FQDN
#   ${memtier_package}       - Memtier benchmark download URL
#   ${prometheus_package}    - Prometheus download URL
#   ${grafana_version}       - Grafana version to install
#   ${java_version}          - Java version to install (e.g., 21)
#
# Note: RedisInsight is installed via Docker (redis/redisinsight:latest)
# =============================================================================

set -x  # Debug mode - log all commands
exec > >(tee /var/log/user-data.log) 2>&1

LOG_FILE="/home/${ssh_user}/prepare_client.log"
INSTALL_DIR="/home/${ssh_user}/install"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Wait for cloud-init to create the user (AWS/Azure specific)
while [ ! -d /home/${ssh_user} ]; do
    echo "Waiting for /home/${ssh_user} to be created..."
    sleep 5
done

log "=== Starting bastion preparation ==="

# =============================================================================
# Wait for cloud-init to complete (critical for apt lock)
# =============================================================================
log "Waiting for cloud-init to complete..."
if command -v cloud-init >/dev/null 2>&1; then
    cloud-init status --wait || true
fi

# Also wait for any running apt processes to finish
log "Waiting for apt locks to be released..."
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
      fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
      fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
    log "Waiting for apt lock to be released..."
    sleep 5
done

log "Cloud-init complete, apt locks released"

# =============================================================================
# APT Configuration - Non-interactive mode
# =============================================================================
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Disable needrestart interactive prompts (Ubuntu 22.04+)
if [ -d /etc/needrestart/conf.d ]; then
    cat > /etc/needrestart/conf.d/99-disable-interactive.conf << 'NEEDRESTART_EOF'
$nrconf{restart} = 'a';
$nrconf{kernelhints} = 0;
NEEDRESTART_EOF
fi

# =============================================================================
# System Packages - Debug and Development Tools
# =============================================================================
log "Installing system packages..."
apt-get -y update
apt-get -y install \
    vim nano \
    htop iotop \
    iputils-ping \
    netcat-openbsd telnet \
    dnsutils bind9-dnsutils \
    curl wget \
    tcpdump nmap mtr-tiny traceroute \
    jq \
    openssl ca-certificates \
    python3 python3-pip python3-venv \
    openjdk-${java_version}-jdk \
    build-essential autoconf automake \
    libpcre3-dev libevent-dev pkg-config zlib1g-dev libssl-dev \
    apt-transport-https software-properties-common gnupg

# Set timezone
export TZ="UTC"
apt-get install -y tzdata
ln -fs /usr/share/zoneinfo/Europe/Paris /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata

log "System packages installed"

# =============================================================================
# Create install directory
# =============================================================================
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# =============================================================================
# Memtier Benchmark
# =============================================================================
log "Installing memtier_benchmark from: ${memtier_package}"
wget -O memtier.tar.gz "${memtier_package}"
tar xfz memtier.tar.gz
mv memtier_benchmark-*/ memtier

pushd memtier
autoreconf -ivf
./configure
make -j$(nproc)
sudo make install
popd

log "memtier_benchmark installed"

# =============================================================================
# Redis CLI (via apt from redis-debian repository)
# https://github.com/redis/redis-debian
# =============================================================================
log "Installing redis-cli via apt (redis-tools package)"

# Add Redis apt repository
curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list

# Install redis-tools only (contains redis-cli and redis-benchmark, no server)
apt-get update
apt-get install -y redis-tools

# Ensure redis-server is NOT running (in case it got pulled as dependency)
systemctl stop redis-server 2>/dev/null || true
systemctl disable redis-server 2>/dev/null || true

log "redis-cli installed: $(redis-cli --version)"

# =============================================================================
# Prometheus
# =============================================================================
log "Installing Prometheus from: ${prometheus_package}"
wget -O prometheus.tar.gz "${prometheus_package}"
tar xfz prometheus.tar.gz
mv prometheus-*/ prometheus

# Create prometheus user and directories
groupadd --system prometheus || true
useradd -s /sbin/nologin --system -g prometheus prometheus || true
mkdir -p /var/lib/prometheus
for i in rules rules.d files_sd; do mkdir -p /etc/prometheus/$i; done

# Install binaries
mv prometheus/prometheus prometheus/promtool /usr/local/bin/
mv prometheus/consoles/ prometheus/console_libraries/ /etc/prometheus/

# Prometheus configuration for Redis Enterprise (v2 metrics)
# Reference: https://github.com/redis-field-engineering/redis-enterprise-observability
cat > /etc/prometheus/prometheus.yml << 'PROMCONFIG'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

# Alertmanager configuration (optional - uncomment if using alertmanager)
# alerting:
#   alertmanagers:
#     - static_configs:
#         - targets:
#           - alertmanager:9093

# Load alert rules from redis-enterprise-observability
rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: "redis-enterprise"
    scheme: https
    tls_config:
      insecure_skip_verify: true
    scrape_interval: 30s
    scrape_timeout: 30s
    metrics_path: /v2
    static_configs:
      - targets: ['${cluster_dns}:8070']
        labels:
          cluster: '${cluster_dns}'
PROMCONFIG

# Replace cluster_dns placeholder
sed -i "s/\${cluster_dns}/${cluster_dns}/g" /etc/prometheus/prometheus.yml

# Download Prometheus alert rules from redis-enterprise-observability
log "Downloading Prometheus alert rules..."
mkdir -p /etc/prometheus/rules

OBSERVABILITY_REPO="https://raw.githubusercontent.com/redis-field-engineering/redis-enterprise-observability/main/prometheus_v2/rules"

# Download all alert rule files
for rule_file in alerts.yml capacity-alerts.yml connection-alerts.yml latency-alerts.yml node-alerts.yml shard-alerts.yml synchronization-alerts.yml throughput-alerts.yml utilization-alerts.yml; do
    wget -q -O /etc/prometheus/rules/$rule_file "$OBSERVABILITY_REPO/$rule_file" || log "Warning: Could not download $rule_file"
done

chown -R prometheus:prometheus /etc/prometheus/rules
log "Prometheus alert rules configured"

# Prometheus systemd service
cat > /etc/systemd/system/prometheus.service << 'PROMSERVICE'
[Unit]
Description=Prometheus Service
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090 \
  --web.external-url=

Restart=always

[Install]
WantedBy=multi-user.target
PROMSERVICE

# Set permissions
for i in rules rules.d files_sd; do chown -R prometheus:prometheus /etc/prometheus/$i; done
for i in rules rules.d files_sd; do chmod -R 775 /etc/prometheus/$i; done
chown -R prometheus:prometheus /var/lib/prometheus/

log "Prometheus installed"

# =============================================================================
# Grafana (specific version)
# =============================================================================
log "Installing Grafana ${grafana_version}..."

# Add Grafana repository
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor > /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list

apt-get -y update
apt-get install -y grafana-enterprise=${grafana_version}

log "Grafana installed"

# =============================================================================
# Docker
# =============================================================================
log "Installing Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
groupadd docker || true
usermod -aG docker ${ssh_user}

log "Docker installed"

# =============================================================================
# RedisInsight via Docker
# =============================================================================
log "Starting RedisInsight container..."

# Ensure Docker service is running
systemctl enable docker
systemctl start docker

# Wait for Docker to be ready
sleep 5

# Run RedisInsight container with persistent volume
# Explicitly bind to 0.0.0.0 to allow external access
docker run -d \
    --name redisinsight \
    --restart unless-stopped \
    -p 0.0.0.0:5540:5540 \
    -v redisinsight:/data \
    redis/redisinsight:latest

log "RedisInsight container started on port 5540"

# =============================================================================
# Grafana Configuration - Link to Prometheus
# =============================================================================
log "Configuring Grafana datasources..."

cat > /etc/grafana/provisioning/datasources/prometheus.yaml << 'GRAFANADS'
apiVersion: 1
datasources:
- name: Prometheus
  type: prometheus
  access: proxy
  url: http://127.0.0.1:9090
  isDefault: true
GRAFANADS

# Dashboard provisioning with multiple folders
cat > /etc/grafana/provisioning/dashboards/dashboards.yaml << 'GRAFANADASH'
apiVersion: 1
providers:
- name: 'redis-enterprise-basic'
  orgId: 1
  folder: 'Redis Enterprise'
  type: file
  disableDeletion: false
  updateIntervalSeconds: 30
  options:
    path: /var/lib/grafana/dashboards/basic
- name: 'redis-enterprise-databases'
  orgId: 1
  folder: 'Redis Enterprise / Databases'
  type: file
  disableDeletion: false
  updateIntervalSeconds: 30
  options:
    path: /var/lib/grafana/dashboards/databases
- name: 'redis-enterprise-nodes'
  orgId: 1
  folder: 'Redis Enterprise / Nodes'
  type: file
  disableDeletion: false
  updateIntervalSeconds: 30
  options:
    path: /var/lib/grafana/dashboards/nodes
GRAFANADASH

mkdir -p /var/lib/grafana/dashboards/{basic,databases,nodes}

# Download Redis Enterprise v2 dashboards from redis-enterprise-observability
# Reference: https://github.com/redis-field-engineering/redis-enterprise-observability
log "Downloading Grafana v2 dashboards from redis-enterprise-observability..."

DASHBOARD_REPO="https://raw.githubusercontent.com/redis-field-engineering/redis-enterprise-observability/main/grafana_v2/dashboards/grafana_v9-11"

# Basic dashboards (software)
log "Downloading basic dashboards..."
wget -q -O /var/lib/grafana/dashboards/basic/redis-software-cluster-dashboard.json \
    "$DASHBOARD_REPO/software/basic/redis-software-cluster-dashboard_v9-11.json"
wget -q -O /var/lib/grafana/dashboards/basic/redis-software-database-dashboard.json \
    "$DASHBOARD_REPO/software/basic/redis-software-database-dashboard_v9-11.json"
wget -q -O /var/lib/grafana/dashboards/basic/redis-software-node-dashboard.json \
    "$DASHBOARD_REPO/software/basic/redis-software-node-dashboard_v9-11.json"
wget -q -O /var/lib/grafana/dashboards/basic/redis-software-shard-dashboard.json \
    "$DASHBOARD_REPO/software/basic/redis-software-shard-dashboard_v9-11.json"
wget -q -O /var/lib/grafana/dashboards/basic/redis-software-active-active-dashboard.json \
    "$DASHBOARD_REPO/software/basic/redis-software-active-active-dashboard_v9-11.json"
wget -q -O /var/lib/grafana/dashboards/basic/redis-software-synchronization-overview.json \
    "$DASHBOARD_REPO/software/basic/redis-software-synchronization-overview_v9-11.json"

# Workflow dashboards - Databases drill-down
log "Downloading database workflow dashboards..."
wget -q -O /var/lib/grafana/dashboards/databases/redis-software-cluster-databases.json \
    "$DASHBOARD_REPO/workflow/databases/redis-software-cluster-databases_v9-11.json"
wget -q -O /var/lib/grafana/dashboards/databases/redis-software-cluster-database-cpu.json \
    "$DASHBOARD_REPO/workflow/databases/redis-software-cluster-database-cpu_v9-11.json"
wget -q -O /var/lib/grafana/dashboards/databases/redis-software-cluster-database-latency.json \
    "$DASHBOARD_REPO/workflow/databases/redis-software-cluster-database-latency_v9-11.json"
wget -q -O /var/lib/grafana/dashboards/databases/redis-software-cluster-database-memory.json \
    "$DASHBOARD_REPO/workflow/databases/redis-software-cluster-database-memory_v9-11.json"
wget -q -O /var/lib/grafana/dashboards/databases/redis-software-cluster-database-requests.json \
    "$DASHBOARD_REPO/workflow/databases/redis-software-cluster-database-requests_v9-11.json"

# Workflow dashboards - Nodes drill-down
log "Downloading node workflow dashboards..."
wget -q -O /var/lib/grafana/dashboards/nodes/redis-software-cluster-nodes.json \
    "$DASHBOARD_REPO/workflow/nodes/redis-software-cluster-nodes_v9-11.json"
wget -q -O /var/lib/grafana/dashboards/nodes/redis-software-cluster-node-cpu.json \
    "$DASHBOARD_REPO/workflow/nodes/redis-software-cluster-node-cpu_v9-11.json"
wget -q -O /var/lib/grafana/dashboards/nodes/redis-software-cluster-node-latency.json \
    "$DASHBOARD_REPO/workflow/nodes/redis-software-cluster-node-latency_v9-11.json"
wget -q -O /var/lib/grafana/dashboards/nodes/redis-software-cluster-node-memory.json \
    "$DASHBOARD_REPO/workflow/nodes/redis-software-cluster-node-memory_v9-11.json"
wget -q -O /var/lib/grafana/dashboards/nodes/redis-software-cluster-node-requests.json \
    "$DASHBOARD_REPO/workflow/nodes/redis-software-cluster-node-requests_v9-11.json"

# Fix datasource references in all dashboards
log "Configuring dashboard datasources..."
find /var/lib/grafana/dashboards -name "*.json" -exec sed -i 's/\$${DS_PROMETHEUS}/Prometheus/g' {} \;

chown -R grafana:grafana /var/lib/grafana/dashboards

log "Grafana v2 dashboards configured (17 dashboards total)"

# =============================================================================
# Python packages for Redis
# =============================================================================
log "Installing Python Redis packages..."
pip3 install --break-system-packages redis hiredis

log "Python packages installed"

# =============================================================================
# Fix ownership
# =============================================================================
chown -R ${ssh_user}:${ssh_user} "$INSTALL_DIR"
chown -R ${ssh_user}:${ssh_user} /home/${ssh_user}/.local

# =============================================================================
# Start Services
# =============================================================================
log "Starting services..."

systemctl daemon-reload

# Prometheus
systemctl enable prometheus
systemctl start prometheus

# Grafana
systemctl enable grafana-server
systemctl start grafana-server

# Verify services
systemctl status prometheus --no-pager >> "$LOG_FILE" 2>&1 || true
systemctl status grafana-server --no-pager >> "$LOG_FILE" 2>&1 || true

# =============================================================================
# Summary
# =============================================================================
log "=== Bastion preparation complete ==="
log ""
log "Installed tools:"
log "  - memtier_benchmark: $(memtier_benchmark --version 2>&1 | head -1 || echo 'check PATH')"
log "  - redis-cli:         $(redis-cli --version 2>&1 || echo 'in ~/.local/bin')"
log "  - java:              $(java -version 2>&1 | head -1)"
log "  - python3:           $(python3 --version)"
log "  - docker:            $(docker --version)"
log ""
log "Services running on:"
log "  - Prometheus:    http://localhost:9090 (with Redis Enterprise alert rules)"
log "  - Grafana:       http://localhost:3000 (admin/admin)"
log "  - RedisInsight:  http://localhost:5540"
log ""
log "Grafana Dashboards (redis-enterprise-observability v2):"
log "  - Redis Enterprise: Cluster, Database, Node, Shard, Active-Active, Sync"
log "  - Databases workflow: Overview, CPU, Latency, Memory, Requests"
log "  - Nodes workflow: Overview, CPU, Latency, Memory, Requests"
log ""
log "Prometheus Alert Rules:"
log "  - Capacity, Connections, Latency, Nodes, Shards"
log "  - Synchronization, Throughput, Utilization"
log ""
log "Redis cluster configured: ${cluster_dns}"
log "Metrics endpoint: https://${cluster_dns}:8070/v2"

