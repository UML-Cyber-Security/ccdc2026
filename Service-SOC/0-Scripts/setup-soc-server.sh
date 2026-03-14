#!/bin/bash

# WHAT THIS SCRIPT DOES:
# Sets up the SOC/Grafana server with:
#   - Loki v2.9.3       (log aggregation on port 3100)
#   - Prometheus        (metrics on port 9090)
#   - Grafana           (dashboards on port 3000)
#   - Promtail config   (updates existing install to ship local logs to Loki)
#
# Usage: sudo ./setup-soc-server.sh

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

source /etc/os-release

# ─── Install dependencies ────────────────────────────────────────────────────
echo "[0/4] Installing dependencies..."
if [[ "$ID" == "ubuntu" || "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
    apt-get update -y
    apt-get install -y curl wget unzip gnupg adduser libfontconfig1
elif [[ "$ID_LIKE" == *"rhel"* || "$ID" == "rocky" || "$ID" == "almalinux" || "$ID" == "centos" ]]; then
    dnf install -y curl wget unzip gnupg2 || yum install -y curl wget unzip gnupg2
fi

# ─── Install Loki ────────────────────────────────────────────────────────────
echo "[1/4] Installing Loki..."
cd /tmp
wget -q https://github.com/grafana/loki/releases/download/v2.9.3/loki-linux-amd64.zip
unzip -o loki-linux-amd64.zip
mv loki-linux-amd64 /usr/local/bin/loki
chmod +x /usr/local/bin/loki

mkdir -p /etc/loki /var/lib/loki

tee /etc/loki/loki-config.yaml > /dev/null <<'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  instance_addr: 127.0.0.1
  path_prefix: /var/lib/loki
  storage:
    filesystem:
      chunks_directory: /var/lib/loki/chunks
      rules_directory: /var/lib/loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
EOF

tee /etc/systemd/system/loki.service > /dev/null <<'EOF'
[Unit]
Description=Loki Log Aggregation
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/loki -config.file=/etc/loki/loki-config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now loki
echo "  ✓ Loki running on :3100"

# ─── Install Prometheus ──────────────────────────────────────────────────────
echo "[2/4] Installing Prometheus..."
cd /tmp
wget -q https://github.com/prometheus/prometheus/releases/download/v2.49.1/prometheus-2.49.1.linux-amd64.tar.gz
tar xzf prometheus-2.49.1.linux-amd64.tar.gz
mv prometheus-2.49.1.linux-amd64/prometheus /usr/local/bin/
mv prometheus-2.49.1.linux-amd64/promtool /usr/local/bin/

mkdir -p /etc/prometheus /var/lib/prometheus

tee /etc/prometheus/prometheus.yaml > /dev/null <<'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ['localhost:9090']

  # SOC server's own node metrics
  - job_name: node_soc
    static_configs:
      - targets: ['localhost:9100']
        labels:
          host: soc-server

  # Client node exporters — add entries here as you onboard machines
  # - job_name: node_clients
  #   static_configs:
  #     - targets:
  #         - '192.168.1.10:9100'
  #         - '192.168.1.11:9100'
  #       labels:
  #         job: node
EOF

tee /etc/systemd/system/prometheus.service > /dev/null <<'EOF'
[Unit]
Description=Prometheus
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yaml \
  --storage.tsdb.path=/var/lib/prometheus
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now prometheus
echo "  ✓ Prometheus running on :9090"

# ─── Install Grafana ─────────────────────────────────────────────────────────
echo "[3/4] Installing Grafana..."
if [[ "$ID" == "ubuntu" || "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
    wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
    echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" \
        | tee /etc/apt/sources.list.d/grafana.list
    apt-get update -y
    apt-get install -y grafana
elif [[ "$ID_LIKE" == *"rhel"* || "$ID" == "rocky" || "$ID" == "almalinux" || "$ID" == "centos" ]]; then
    tee /etc/yum.repos.d/grafana.repo > /dev/null <<'REPO'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
REPO
    yum install -y grafana
fi

systemctl daemon-reload
systemctl enable --now grafana-server
echo "  ✓ Grafana running on :3000  (admin / admin)"

# ─── Update Promtail config (already installed) ──────────────────────────────
echo "[4/4] Updating Promtail config for SOC server..."

# Detect which config file is in use
PROMTAIL_CONFIG=""
for f in /etc/promtail/config.yaml /etc/promtail/config.yml; do
    [ -f "$f" ] && PROMTAIL_CONFIG="$f" && break
done

if [ -z "$PROMTAIL_CONFIG" ]; then
    echo "  ! Could not find Promtail config in /etc/promtail/ — skipping"
else
    cp "$PROMTAIL_CONFIG" "${PROMTAIL_CONFIG}.bak"
    echo "  Backed up existing config to ${PROMTAIL_CONFIG}.bak"

    tee "$PROMTAIL_CONFIG" > /dev/null <<'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  - job_name: varlogs
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          host: soc-server
          __path__: /var/log/*.log

  - job_name: syslog
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          host: soc-server
          __path__: /var/log/{syslog,messages}

  - job_name: auth
    static_configs:
      - targets:
          - localhost
        labels:
          job: auth
          host: soc-server
          __path__: /var/log/{auth.log,secure}

  - job_name: auditd
    static_configs:
      - targets:
          - localhost
        labels:
          job: auditd
          host: soc-server
          __path__: /var/log/audit/audit.log

  - job_name: sysmon
    journal:
      matches: SYSLOG_IDENTIFIER=sysmon
      labels:
        job: sysmon
        host: soc-server
    relabel_configs:
      - source_labels: [__journal__hostname]
        target_label: host
        replacement: "$1"
EOF

    systemctl restart promtail
    echo "  ✓ Promtail config updated and restarted"
fi

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "=== SOC Server Setup Complete ==="
SOC_IP=$(hostname -I | awk '{print $1}')
echo "  Loki:       http://${SOC_IP}:3100"
echo "  Prometheus: http://${SOC_IP}:9090"
echo "  Grafana:    http://${SOC_IP}:3000  (login: admin / admin)"
echo ""
echo "Next steps in Grafana:"
echo "  1. Add Loki datasource       → http://localhost:3100"
echo "  2. Add Prometheus datasource → http://localhost:9090"
echo "  3. Import dashboard ID 1860  (Node Exporter Full)"