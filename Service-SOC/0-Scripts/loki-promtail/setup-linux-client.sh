#!/bin/bash

# WHAT THIS SCRIPT DOES: 
# Sets up a Linux client with Node Exporter, Promtail, and Falco to send metrics and logs to a SOC server for all linux machines.

# Usage: sudo ./setup-linux-client.sh <hostname> <soc_server_ip>

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: sudo $0 <hostname> <soc_server_ip>"
    exit 1
fi

HOSTNAME=$1
SOC_SERVER=$2

echo "=== Setting up monitoring for: $HOSTNAME ==="

# Install Node Exporter
echo "[1/4] Installing Node Exporter..."
cd /tmp
wget -q https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xzf node_exporter-1.7.0.linux-amd64.tar.gz
sudo mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
sudo chmod +x /usr/local/bin/node_exporter

sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
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

sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

# Install Promtail
echo "[2/4] Installing Promtail..."
wget -q https://github.com/grafana/loki/releases/download/v2.9.3/promtail-linux-amd64.zip
sudo apt install -y unzip 2>/dev/null || sudo yum install -y unzip 2>/dev/null
unzip -o promtail-linux-amd64.zip
sudo mv promtail-linux-amd64 /usr/local/bin/promtail
sudo chmod +x /usr/local/bin/promtail
sudo mkdir -p /etc/promtail /var/lib/promtail

sudo tee /etc/promtail/config.yaml > /dev/null <<EOF
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
          __path__: /var/log/syslog

  - job_name: auth
    static_configs:
      - targets:
          - localhost
        labels:
          job: auth
          host: ${HOSTNAME}
          __path__: /var/log/auth.log

  - job_name: falco
    static_configs:
      - targets:
          - localhost
        labels:
          job: falco
          host: ${HOSTNAME}
          __path__: /var/log/falco/*.json
EOF

sudo tee /etc/systemd/system/promtail.service > /dev/null <<EOF
[Unit]
Description=Promtail
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now promtail

# Install Falco
echo "[3/4] Installing Falco..."
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg 2>/dev/null
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | sudo tee /etc/apt/sources.list.d/falcosecurity.list
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y falco

sudo mkdir -p /var/log/falco /etc/falco/config.d
sudo tee /etc/falco/config.d/custom-output.yaml > /dev/null <<EOF
json_output: true
json_include_output_property: true

file_output:
  enabled: true
  keep_alive: false
  filename: /var/log/falco/alerts.json
EOF

sudo systemctl enable falco-modern-bpf 2>/dev/null || sudo systemctl enable falco
sudo systemctl restart falco-modern-bpf 2>/dev/null || sudo systemctl restart falco

# Install rsyslog if needed
echo "[4/4] Ensuring rsyslog is installed..."
sudo apt install -y rsyslog 2>/dev/null
sudo systemctl enable --now rsyslog 2>/dev/null

echo ""
echo "=== Setup Complete for $HOSTNAME ==="
echo "Node Exporter: http://$(hostname -I | awk '{print $1}'):9100"
echo "Promtail: http://$(hostname -I | awk '{print $1}'):9080"