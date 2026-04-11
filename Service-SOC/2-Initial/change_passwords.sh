#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

# Paste your pre-generated master hash here
MASTER_HASH="paste_your_hash_here"

change_password() {
    local username=$1

    # Skip blackteam accounts - out of scope
    if [[ "$username" == blackteam* ]]; then
        echo "Skipped (blackteam): $username"
        return
    fi

    local derived_pass=$(echo "$MASTER_HASH:$username" | openssl dgst -sha256 | awk '{print $2}')
    local hashed=$(openssl passwd -6 "$derived_pass")
    echo "$username:$hashed" | chpasswd -e
    echo "Changed: $username"
    sleep 2
}

change_password "root"

while IFS=: read -r username _ uid _ _ _ shell; do
    if [[ "$uid" -ge 1000 && "$shell" != */nologin && "$shell" != */false ]]; then
        change_password "$username"
    fi
done < /etc/passwd