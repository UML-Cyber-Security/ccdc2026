#!/bin/bash

NEW_PASS="CHANGE_TO_SECURE_PASS"

echo "root:$NEW_PASS" | chpasswd
echo "Changed: root"

while IFS=: read -r username _ uid _ _ _ shell; do
    if [[ "$uid" -ge 1000 && "$shell" != */nologin && "$shell" != */false ]]; then
        echo "$username:$NEW_PASS" | chpasswd
        echo "Changed: $username"
    fi
done < /etc/passwd