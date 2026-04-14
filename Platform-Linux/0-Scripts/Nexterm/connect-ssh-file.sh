#!/bin/bash

NEXTERM_URL="http://localhost:6989"

echo "============================================"
echo "       Nexterm SSH Bulk Agent Connect Tool      "
echo "============================================"
echo ""

# --- Check for input file ---
if [ -z "$1" ]; then
  echo "Usage: ./connect-agents-file.sh servers.txt"
  exit 1
fi

if [ ! -f "$1" ]; then
  echo "[!] File not found: $1"
  exit 1
fi

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

# --- Helper: check if value looks like an IP ---
is_ip() {
  echo "$1" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
}

# --- Helper: check if value is a port number ---
is_port() {
  echo "$1" | grep -qE '^[0-9]+$' && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

# --- Parse and process file ---
# Read entire file, split on commas to get blocks
while IFS= read -r line || [ -n "$line" ]; do
  # Strip whitespace
  line=$(echo "$line" | tr -d '\r' | xargs)
  [ -z "$line" ] && continue

  # Check if line ends with comma = end of a server block
  if echo "$line" | grep -q ',$'; then
    # Remove trailing comma and add last line to block
    line=$(echo "$line" | sed 's/,$//')
    [ -n "$line" ] && BLOCK_LINES+=("$line")
    PROCESS_BLOCK=true
  else
    BLOCK_LINES+=("$line")
    PROCESS_BLOCK=false
  fi

  # If end of block or end of file, process it
  if [ "$PROCESS_BLOCK" = true ] || [ ${#BLOCK_LINES[@]} -gt 0 ]; then
    if [ "$PROCESS_BLOCK" = true ]; then

      NAME=""
      IP=""
      PORT="22"
      USERNAME=""
      PASSWORD=""
      CREDS=()

      for val in "${BLOCK_LINES[@]}"; do
        if [ -z "$NAME" ]; then
          NAME="$val"
        elif is_ip "$val" && [ -z "$IP" ]; then
          IP="$val"
        elif is_port "$val" && [ -n "$IP" ] && [ "$PORT" = "22" ] && [ "$val" != "22" -o ${#CREDS[@]} -eq 0 ]; then
          PORT="$val"
        else
          CREDS+=("$val")
        fi
      done

      [ ${#CREDS[@]} -ge 1 ] && USERNAME="${CREDS[0]}"
      [ ${#CREDS[@]} -ge 2 ] && PASSWORD="${CREDS[1]}"

      # Reset block
      BLOCK_LINES=()

      if [ -z "$NAME" ] || [ -z "$IP" ]; then
        echo "[!] Skipping incomplete entry"
        continue
      fi

      echo "--- Processing: $NAME ($IP:$PORT) ---"

      IDENTITY_IDS="[]"

      if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
        echo "  [*] Creating identity for $USERNAME..."
        IDENTITY_RESPONSE=$(curl -s -X PUT "$NEXTERM_URL/api/identities" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d "{\"name\":\"${NAME}-creds\",\"type\":\"password\",\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")

        IDENTITY_ID=$(echo "$IDENTITY_RESPONSE" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')

        if [ -z "$IDENTITY_ID" ]; then
          echo "  [!] Failed to create identity: $IDENTITY_RESPONSE"
          echo "  [!] Adding entry without identity..."
        else
          echo "  [+] Identity created (id: $IDENTITY_ID)"
          IDENTITY_IDS="[$IDENTITY_ID]"
        fi
      else
        echo "  [*] No credentials provided - adding without identity"
      fi

      ENTRY_RESPONSE=$(curl -s -X PUT "$NEXTERM_URL/api/entries" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$NAME\",\"type\":\"server\",\"identities\":$IDENTITY_IDS,\"config\":{\"protocol\":\"ssh\",\"ip\":\"$IP\",\"port\":$PORT}}")

      ENTRY_ID=$(echo "$ENTRY_RESPONSE" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')

      if [ -z "$ENTRY_ID" ]; then
        echo "  [!] Failed to add entry: $ENTRY_RESPONSE"
      else
        echo "  [+] '$NAME' added successfully (id: $ENTRY_ID)"
      fi

      echo ""
    fi
  fi

done < "$1"

# --- Handle last block if file doesn't end with comma ---
if [ ${#BLOCK_LINES[@]} -gt 0 ]; then
  NAME=""
  IP=""
  PORT="22"
  USERNAME=""
  PASSWORD=""
  CREDS=()

  for val in "${BLOCK_LINES[@]}"; do
    if [ -z "$NAME" ]; then
      NAME="$val"
    elif is_ip "$val" && [ -z "$IP" ]; then
      IP="$val"
    elif is_port "$val" && [ -n "$IP" ]; then
      PORT="$val"
    else
      CREDS+=("$val")
    fi
  done

  [ ${#CREDS[@]} -ge 1 ] && USERNAME="${CREDS[0]}"
  [ ${#CREDS[@]} -ge 2 ] && PASSWORD="${CREDS[1]}"

  if [ -n "$NAME" ] && [ -n "$IP" ]; then
    echo "--- Processing: $NAME ($IP:$PORT) ---"

    IDENTITY_IDS="[]"

    if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
      echo "  [*] Creating identity for $USERNAME..."
      IDENTITY_RESPONSE=$(curl -s -X PUT "$NEXTERM_URL/api/identities" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"${NAME}-creds\",\"type\":\"password\",\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")

      IDENTITY_ID=$(echo "$IDENTITY_RESPONSE" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')

      if [ -z "$IDENTITY_ID" ]; then
        echo "  [!] Failed to create identity: $IDENTITY_RESPONSE"
      else
        echo "  [+] Identity created (id: $IDENTITY_ID)"
        IDENTITY_IDS="[$IDENTITY_ID]"
      fi
    else
      echo "  [*] No credentials provided - adding without identity"
    fi

    ENTRY_RESPONSE=$(curl -s -X PUT "$NEXTERM_URL/api/entries" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"$NAME\",\"type\":\"server\",\"identities\":$IDENTITY_IDS,\"config\":{\"protocol\":\"ssh\",\"ip\":\"$IP\",\"port\":$PORT}}")

    ENTRY_ID=$(echo "$ENTRY_RESPONSE" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')

    if [ -z "$ENTRY_ID" ]; then
      echo "  [!] Failed to add entry: $ENTRY_RESPONSE"
    else
      echo "  [+] '$NAME' added successfully (id: $ENTRY_ID)"
    fi
    echo ""
  fi
fi

echo "[+] Done. Check the Nexterm UI at $NEXTERM_URL"