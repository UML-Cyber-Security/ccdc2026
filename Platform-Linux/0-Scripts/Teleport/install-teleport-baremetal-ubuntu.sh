#!/bin/bash
# =============================================================================
# Teleport Universal Bare Metal Installer
# Ubuntu 20.04 / 22.04 / 24.04
# =============================================================================

set -e

# --- Helpers ------------------------------------------------------------------

section() { echo ""; echo "=== $1 ==="; }
prompt() {
  local var_name=$1 prompt_text=$2 default=$3 value
  if [ -n "$default" ]; then
    read -rp "${prompt_text} [${default}] (Press Enter for Default Configuration): " value
    value="${value:-$default}"
  else
    while [ -z "$value" ]; do
      read -rp "${prompt_text}: " value
      [ -z "$value" ] && echo "This field is required."
    done
  fi
  eval "$var_name=\"$value\""
}
generate_token() { openssl rand -hex 20; }

# --- Banner -------------------------------------------------------------------

echo ""
echo "============================================="
echo "   Teleport Universal Bare Metal Installer   "
echo "============================================="
echo ""

# --- Gather Input -------------------------------------------------------------

section "Cluster"
prompt CLUSTER_NAME  "Cluster name"                          "my-teleport-cluster"
prompt NODE_NAME     "Node name (hostname of this server)"   "$(hostname)"

section "Proxy / Domain"
prompt PUBLIC_DOMAIN "Public domain (e.g. teleport.example.com)" ""
prompt WEB_PORT      "Web UI port"                           "3080"
prompt TUNNEL_PORT   "Tunnel port"                           "3024"
prompt AUTH_PORT     "Auth port"                             "3025"
prompt SSH_PORT      "Node SSH port"                         "3022"

section "Node Tokens"
prompt TOKEN_COUNT   "How many node tokens to generate (1-9)" "9"
if ! [[ "$TOKEN_COUNT" =~ ^[1-9]$ ]]; then
  echo "Invalid token count. Defaulting to 9."
  TOKEN_COUNT=9
fi

section "Admin User"
prompt ADMIN_USER    "Admin username"                        "admin"
prompt ADMIN_ROLES   "Teleport roles"                        "editor,access"
prompt ADMIN_LOGINS  "Allowed SSH logins (comma-separated)"  "ubuntu,root"

section "Teleport Version"
prompt TELEPORT_VER  "Teleport major version"                "v18"

# TLS defaults — no prompt
CERT_CN="$PUBLIC_DOMAIN"
CERT_DAYS=365

# --- Confirm ------------------------------------------------------------------

echo ""
echo "============================================="
echo "         Review Your Configuration"
echo "============================================="
echo "  Cluster name     : $CLUSTER_NAME"
echo "  Node name        : $NODE_NAME"
echo "  Public domain    : $PUBLIC_DOMAIN"
echo "  Web UI port      : $WEB_PORT"
echo "  Tunnel port      : $TUNNEL_PORT"
echo "  Auth port        : $AUTH_PORT"
echo "  Node SSH port    : $SSH_PORT"
echo "  Token count      : $TOKEN_COUNT"
echo "  Cert CN          : $CERT_CN (auto)"
echo "  Cert validity    : $CERT_DAYS days (auto)"
echo "  Admin user       : $ADMIN_USER"
echo "  Admin roles      : $ADMIN_ROLES"
echo "  Admin logins     : $ADMIN_LOGINS"
echo "  Teleport version : $TELEPORT_VER"
echo ""
read -rp "Proceed with installation? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Installation cancelled."
  exit 0
fi

# --- Step 1: System Update ----------------------------------------------------

section "Step 1 — Updating System"
sudo apt-get update && sudo apt-get upgrade -y
echo "Done."

# --- Step 2: Install Teleport -------------------------------------------------

section "Step 2 — Installing Teleport ${TELEPORT_VER}"
sudo curl -fsSL https://apt.releases.teleport.dev/gpg \
  -o /usr/share/keyrings/teleport-archive-keyring.asc

source /etc/os-release
echo "deb [signed-by=/usr/share/keyrings/teleport-archive-keyring.asc] \
https://apt.releases.teleport.dev/${ID?} ${VERSION_CODENAME?} stable/${TELEPORT_VER}" \
  | sudo tee /etc/apt/sources.list.d/teleport.list > /dev/null

sudo apt-get update
sudo apt-get install teleport -y
echo "Installed: $(teleport version)"

# --- Step 3: Firewall ---------------------------------------------------------

section "Step 3 — Configuring Firewall"
sudo ufw allow ${AUTH_PORT}/tcp   2>/dev/null || true
sudo ufw allow ${WEB_PORT}/tcp    2>/dev/null || true
sudo ufw allow ${TUNNEL_PORT}/tcp 2>/dev/null || true
sudo ufw allow ${SSH_PORT}/tcp    2>/dev/null || true
sudo ufw reload 2>/dev/null || true
echo "Ports opened: ${AUTH_PORT}, ${WEB_PORT}, ${TUNNEL_PORT}, ${SSH_PORT}"

# --- Step 4: TLS Certificate --------------------------------------------------

section "Step 4 — Generating TLS Certificate"
sudo mkdir -p /var/lib/teleport
sudo openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout /var/lib/teleport/teleport.key \
  -out /var/lib/teleport/teleport.cert \
  -days "$CERT_DAYS" \
  -subj "/CN=${CERT_CN}" 2>/dev/null
sudo chmod 600 /var/lib/teleport/teleport.key
sudo chown root:root /var/lib/teleport/teleport.key /var/lib/teleport/teleport.cert
sudo openssl x509 -in /var/lib/teleport/teleport.cert -noout -issuer -dates

# --- Step 5: Generate Tokens --------------------------------------------------

section "Step 5 — Generating Secure Node Tokens"
TOKENS=()
for i in $(seq 1 "$TOKEN_COUNT"); do
  TOKEN=$(generate_token)
  TOKENS+=("$TOKEN")
  echo "  Token $i: ${TOKEN}"
done

# --- Step 6: Write Config -----------------------------------------------------

section "Step 6 — Writing /etc/teleport.yaml"
sudo tee /etc/teleport.yaml > /dev/null <<EOF
version: v3
teleport:
  nodename: ${NODE_NAME}
  data_dir: /var/lib/teleport

auth_service:
  enabled: yes
  cluster_name: ${CLUSTER_NAME}
  listen_addr: 0.0.0.0:${AUTH_PORT}
  tokens:
$(printf "  - \"node:%s\"\n" "${TOKENS[@]}")

proxy_service:
  enabled: yes
  web_listen_addr: 0.0.0.0:${WEB_PORT}
  tunnel_listen_addr: 0.0.0.0:${TUNNEL_PORT}
  public_addr: ${PUBLIC_DOMAIN}
  https_keypairs:
    - key_file: /var/lib/teleport/teleport.key
      cert_file: /var/lib/teleport/teleport.cert

ssh_service:
  enabled: no
EOF
echo "Config written. Verify with: cat /etc/teleport.yaml"

# --- Step 7: Permissions ------------------------------------------------------

section "Step 7 — Setting Permissions"
sudo chmod 700 /var/lib/teleport
sudo chown -R root:root /var/lib/teleport
echo "Done."

# --- Step 8: Start Teleport ---------------------------------------------------

section "Step 8 — Starting Teleport"
sudo systemctl enable teleport
sudo systemctl start teleport
sleep 3
sudo systemctl status teleport --no-pager

# --- Step 9: Verify Cluster ---------------------------------------------------

section "Step 9 — Verifying Cluster Health"
echo "Waiting for cluster to initialize... Wait time: 30 Seconds"
sleep 30
sudo tctl status

# --- Step 10: Create Admin User -----------------------------------------------

section "Step 10 — Creating Admin User: ${ADMIN_USER}"
INVITE_OUTPUT=$(sudo tctl users add "$ADMIN_USER" \
  --roles="$ADMIN_ROLES" \
  --logins="$ADMIN_LOGINS" 2>&1)
INVITE_URL=$(echo "$INVITE_OUTPUT" | grep -o 'https://[^ ]*')

# --- Summary ------------------------------------------------------------------

echo ""
echo "============================================="
echo "           Installation Complete!"
echo "============================================="
echo ""
echo "  Web UI  : https://${PUBLIC_DOMAIN}:${WEB_PORT}"
echo "  Cluster : ${CLUSTER_NAME}"
echo "  Admin   : ${ADMIN_USER}"
echo ""
echo "Node Tokens (save these securely):"
for i in "${!TOKENS[@]}"; do
  echo "  Token $((i+1)): ${TOKENS[$i]}"
done
echo ""
echo "Node enrollment config template:"
echo "---"
cat <<EOF
  teleport:
    nodename: <node-hostname>
    data_dir: /var/lib/teleport
    auth_token: "<token from above>"
    auth_servers:
      - ${PUBLIC_DOMAIN}:${AUTH_PORT}
  auth_service:
    enabled: no
  proxy_service:
    enabled: no
  ssh_service:
    enabled: yes
EOF
echo "---"
echo ""
echo "Cert renewal command (due in ${CERT_DAYS} days):"
echo "  sudo openssl req -x509 -newkey rsa:4096 -nodes \\"
echo "    -keyout /var/lib/teleport/teleport.key \\"
echo "    -out /var/lib/teleport/teleport.cert \\"
echo "    -days ${CERT_DAYS} -subj \"/CN=${CERT_CN}\""
echo "  sudo systemctl restart teleport"
echo ""
echo "============================================="
echo "   Admin Account Setup — Complete This Now!"
echo "============================================="
echo "  User      : ${ADMIN_USER}"
echo "  Invite URL: ${INVITE_URL}"
echo "  (Link expires in 1 hour)"
echo "============================================="
echo ""
echo "Done!"