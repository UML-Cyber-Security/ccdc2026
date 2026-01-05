#!/bin/bash
# Script should change the dashboard password for Graylog

set -e

# Setting variables for config files
SERVER_CONF="/etc/graylog/server/server.conf"
DATANODE_CONF="/etc/graylog/datanode/datanode.conf"

# Allows user to set a new secret
read -p "Generate a new password_secret? (DISABLES ALL TOKENS) (y/n): " generate_secret

if [[ "$generate_secret" == "y" ]]; then
    password_secret=$(pwgen -N 1 -s 96)
fi

# Converts password to hashed pass
echo -n "Enter new Graylog admin password: "
read -s root_password
echo
root_password_sha2=$(echo -n "$root_password" | sha256sum | awk '{print $1}')

update_or_add() {
    local key="$1"
    local value="$2"
    local file="$3"

    if grep -q "^${key}[[:space:]]*=" "$file"; then
        sed -i "s|^${key}[[:space:]]*=.*|${key} = ${value}|" "$file"
    else
        echo "${key} = ${value}" >> "$file"
    fi
}

# Modified server.conf
if [[ "$generate_secret" == "y" ]]; then
    update_or_add "password_secret" "$password_secret" "$SERVER_CONF"
fi
update_or_add "root_password_sha2" "$root_password_sha2" "$SERVER_CONF"

# Modified datanode.conf
if [[ "$generate_secret" == "y" ]]; then
    update_or_add "password_secret" "$password_secret" "$DATANODE_CONF"
fi
update_or_add "root_password_sha2" "$root_password_sha2" "$DATANODE_CONF"

# Restart services
systemctl restart graylog-server
systemctl restart graylog-datanode

echo "Graylog credentials updated successfully."
