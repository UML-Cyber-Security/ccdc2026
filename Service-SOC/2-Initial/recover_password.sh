#!/bin/bash

read -s -p "Enter master hash: " MASTER_HASH
echo ""
read -p "Enter username: " USERNAME

derived=$(echo "$MASTER_HASH:$USERNAME" | openssl dgst -sha256 | awk '{print $2}')
echo "Password for $USERNAME: $derived"