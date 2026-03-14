#!/bin/bash

# WHAT THIS SCRIPT DOES:
# Updates the existing Promtail config on a Linux client machine to ship logs
# to the SOC server. Also installs Node Exporter and Falco if not present.
#
# Usage: sudo ./setup-linux-client.sh <hostname> <soc_server_ip>

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: sudo $0 <hostname> <soc_server_ip>"
    exit 1
fi

HOSTNAME=$1
SOC_SERVER=$2

source /etc/os-release

echo "=== Setting up monitoring client: $HOSTNAME → SOC: $SOC_SERVER ==="

# ─── Install dependencies ────────────────────────────────────────────────────
if [[ "$ID" == "ubuntu" || "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
    apt-get update -y
    apt-get install -y curl wget unzip gnupg
elif [[ "$ID_LIKE" == *"rhel"* || "$ID" == "rocky" || "$ID" == "almalinux" || "$ID" == "centos" ]]; then
    dnf install -y curl wget unzip gnupg2 || yum install -y curl wget unzip gnupg2
fi

# ─── Install Node Exporter (if not already installed) ────────────────────────
echo "[1/3] Checking Node Exporter..."
if ! command -v node_exporter &>/dev/null; then
    echo "  Installing Node Exporter..."
    cd /tmp
    wget -q https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
    tar xzf node_exporter-1.7.0.linux-amd64.tar.gz
    mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
    chmod +x /usr/local/bin/node_exporter

    tee /etc/systemd/system/node_exporter.service > /dev/null <<'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now node_exporter
    echo "  ✓ Node Exporter installed and running on :9100"
else
    echo "  ✓ Node Exporter already installed, skipping"
fi

# ─── Install Falco (if not already installed) ────────────────────────────────
echo "[2/3] Checking Falco..."
if ! command -v falco &>/dev/null; then
    echo "  Installing Falco..."
    if [[ "$ID" == "debian" || "$ID" == "ubuntu" || "$ID_LIKE" == *"debian"* ]]; then
        curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | \
            gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | \
            tee /etc/apt/sources.list.d/falcosecurity.list
        apt-get update -y
        apt-get install -y falco
    elif [[ "$ID" == "rhel" || "$ID" == "rocky" || "$ID" == "almalinux" || "$ID" == "centos" || "$ID_LIKE" == *"rhel"* ]]; then
        rpm --import https://falco.org/repo/falcosecurity-packages.asc
        curl -o /etc/yum.repos.d/falcosecurity.repo https://falco.org/repo/falcosecurity-rpm.repo
        yum install -y falco
    fi

    mkdir -p /var/log/falco /etc/falco/config.d

    tee /etc/falco/config.d/custom-output.yaml > /dev/null <<'EOF'
json_output: true
json_include_output_property: true

file_output:
  enabled: true
  keep_alive: false
  filename: /var/log/falco/alerts.json
EOF

    systemctl enable falco-modern-bpf 2>/dev/null || systemctl enable falco
    systemctl restart falco-modern-bpf 2>/dev/null || systemctl restart falco
    echo "  ✓ Falco installed and running"
else
    echo "  ✓ Falco already installed, skipping"
fi

# ─── Update Promtail config (already installed) ──────────────────────────────
echo "[3/3] Updating Promtail config..."

# Detect which config file is in use
PROMTAIL_CONFIG=""
for f in /etc/promtail/config.yaml /etc/promtail/config.yml; do
    [ -f "$f" ] && PROMTAIL_CONFIG="$f" && break
done

if [ -z "$PROMTAIL_CONFIG" ]; then
    echo "  ! Promtail config not found in /etc/promtail/ — creating at /etc/promtail/config.yaml"
    mkdir -p /etc/promtail /var/lib/promtail
    PROMTAIL_CONFIG="/etc/promtail/config.yaml"
else
    cp "$PROMTAIL_CONFIG" "${PROMTAIL_CONFIG}.bak"
    echo "  Backed up existing config to ${PROMTAIL_CONFIG}.bak"
fi

tee "$PROMTAIL_CONFIG" > /dev/null <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: http://${SOC_SERVER}:3100/loki/api/v1/push

scrape_configs:
  - job_name: varlogs
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          host: ${HOSTNAME}
          __path__: /var/log/*.log

  - job_name: syslog
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          host: ${HOSTNAME}
          __path__: /var/log/{syslog,messages}

  - job_name: auth
    static_configs:
      - targets:
          - localhost
        labels:
          job: auth
          host: ${HOSTNAME}
          __path__: /var/log/{auth.log,secure}

  - job_name: falco
    static_configs:
      - targets:
          - localhost
        labels:
          job: falco
          host: ${HOSTNAME}
          __path__: /var/log/falco/*.json

  - job_name: auditd
    static_configs:
      - targets:
          - localhost
        labels:
          job: auditd
          host: ${HOSTNAME}
          __path__: /var/log/audit/audit.log

  - job_name: sysmon
    journal:
      matches: SYSLOG_IDENTIFIER=sysmon
      labels:
        job: sysmon
        host: ${HOSTNAME}
    relabel_configs:
      - source_labels: [__journal__hostname]
        target_label: host
        replacement: "\$1"
EOF

systemctl restart promtail
echo "  ✓ Promtail config updated and restarted"

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "=== Client Setup Complete: $HOSTNAME ==="
CLIENT_IP=$(hostname -I | awk '{print $1}')
echo "  Node Exporter: http://${CLIENT_IP}:9100"
echo "  Promtail:      http://${CLIENT_IP}:9080"
echo ""
echo "Remember to add this machine's Node Exporter to Prometheus on the SOC server:"
echo "  Edit /etc/prometheus/prometheus.yaml and add:"
echo "    - '${CLIENT_IP}:9100'"
echo "  Then: systemctl restart prometheus"