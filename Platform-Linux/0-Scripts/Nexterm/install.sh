#!/bin/bash
set -e

echo "============================================"
echo "          Nexterm Installer                 "
echo "============================================"
echo ""

# --- Prompt for credentials upfront ---
read -p "First name: " NT_FIRST
read -p "Last name: " NT_LAST
read -p "Choose a Nexterm username: " NT_USER
while true; do
  read -sp "Choose a Nexterm password: " NT_PASS
  echo ""
  read -sp "Confirm password: " NT_PASS2
  echo ""
  [ "$NT_PASS" = "$NT_PASS2" ] && break
  echo "[!] Passwords do not match, try again."
done

echo ""
echo "[*] Updating apt..."
sudo apt update -q

echo "[*] Installing Docker..."
sudo apt install -y docker.io

echo "[*] Setting up Nexterm directory..."
mkdir -p ~/nexterm
cd ~/nexterm

echo "[*] Starting Nexterm container..."
sudo docker run -d \
  -e ENCRYPTION_KEY=887c041510fcd80e7ba2cd02165f662197a28a41fff4c98e182181e363a89f76 \
  --network host \
  --name nexterm \
  --restart always \
  -v nexterm:/app/data \
  nexterm/aio:development

echo "[*] Waiting for Nexterm to be ready..."
for i in $(seq 1 20); do
  curl -sf http://localhost:6989 > /dev/null 2>&1 && break
  sleep 2
done

echo "[*] Registering account '$NT_USER'..."
REGISTER_RESPONSE=$(curl -s -X POST "http://localhost:6989/api/accounts/register" \
  -H "Content-Type: application/json" \
  -d "{\"firstName\":\"$NT_FIRST\",\"lastName\":\"$NT_LAST\",\"username\":\"$NT_USER\",\"password\":\"$NT_PASS\"}")

echo "$REGISTER_RESPONSE" | grep -qi "success\|created\|token" \
  && echo "[+] Account created successfully." \
  || echo "[!] Registration response: $REGISTER_RESPONSE"

echo ""
echo "[+] Nexterm is running at http://$(hostname -I | awk '{print $1}'):6989"
echo "[+] Login with username: $NT_USER"