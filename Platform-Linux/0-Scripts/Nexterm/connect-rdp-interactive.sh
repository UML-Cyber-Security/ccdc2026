#!/bin/bash

NEXTERM_URL="http://localhost:6989"

echo "============================================"
echo "       Nexterm RDP Agent Connect Tool       "
echo "============================================"
echo ""

# --- Login ---
read -p "Nexterm username: " NT_USER
read -sp "Nexterm password: " NT_PASS
echo ""

TOKEN=$(curl -s -X POST "$NEXTERM_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$NT_USER\",\"password\":\"$NT_PASS\"}" | \
  grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "[!] Login failed. Check your credentials."
  exit 1
fi

echo "[+] Logged in successfully."
echo ""
echo "Type 'q' at any prompt to finish."
echo ""

# --- Agent loop ---
while true; do
  read -p "Add an agent? (press Enter to continue, q to quit): " CONTINUE
  [ "$CONTINUE" = "q" ] && break

  # Server name
  read -p "  Server name: " SERVER_NAME
  [ "$SERVER_NAME" = "q" ] && break

  # Server IP
  read -p "  Server IP: " SERVER_IP
  [ "$SERVER_IP" = "q" ] && break

  # RDP port
  read -p "  RDP port [3389]: " SERVER_PORT
  [ "$SERVER_PORT" = "q" ] && break
  SERVER_PORT=${SERVER_PORT:-3389}

  # Identity choice
  echo ""
  echo "  Identity options:"
  echo "    a) With identity (save username/password - no prompt on connect)"
  echo "    b) Without identity (prompted for credentials each time)"
  read -p "  Choice (a/b): " ID_CHOICE
  [ "$ID_CHOICE" = "q" ] && break

  IDENTITY_IDS="[]"

  if [ "$ID_CHOICE" = "a" ]; then
    read -p "  RDP username: " RDP_USER
    [ "$RDP_USER" = "q" ] && break
    read -sp "  RDP password: " RDP_PASS
    echo ""
    [ "$RDP_PASS" = "q" ] && break

    echo "  [*] Creating identity..."
    IDENTITY_RESPONSE=$(curl -s -X PUT "$NEXTERM_URL/api/identities" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"${SERVER_NAME}-creds\",\"type\":\"password\",\"username\":\"$RDP_USER\",\"password\":\"$RDP_PASS\"}")

    IDENTITY_ID=$(echo "$IDENTITY_RESPONSE" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')

    if [ -z "$IDENTITY_ID" ]; then
      echo "  [!] Failed to create identity: $IDENTITY_RESPONSE"
      echo "  [!] Skipping this agent."
      continue
    fi

    echo "  [+] Identity created (id: $IDENTITY_ID)"
    IDENTITY_IDS="[$IDENTITY_ID]"
  fi

  # Create entry
  echo "  [*] Adding RDP server entry..."
  ENTRY_RESPONSE=$(curl -s -X PUT "$NEXTERM_URL/api/entries" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"$SERVER_NAME\",
      \"type\": \"server\",
      \"identities\": $IDENTITY_IDS,
      \"config\": {
        \"protocol\": \"rdp\",
        \"ip\": \"$SERVER_IP\",
        \"port\": $SERVER_PORT
      }
    }")

  ENTRY_ID=$(echo "$ENTRY_RESPONSE" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')

  if [ -z "$ENTRY_ID" ]; then
    echo "  [!] Failed to create entry: $ENTRY_RESPONSE"
  else
    echo "  [+] Agent '$SERVER_NAME' ($SERVER_IP:$SERVER_PORT) added successfully (id: $ENTRY_ID)"
  fi

  echo ""
done

echo ""
echo "[+] Done. Your agents are now visible in the Nexterm UI at $NEXTERM_URL"