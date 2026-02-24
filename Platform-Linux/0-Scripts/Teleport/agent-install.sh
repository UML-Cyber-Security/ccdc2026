#!/bin/bash

# Script should be ran on Linux "agent" machines
# Should be easily compatible with ansible-console to quickly enroll Linux agents

# USAGE: ./agent-install.sh <enrollment_token>

set -euo pipefail
if [[ "$EUID" -ne 0 ]]; then
    echo "Error: This script must be run as root."
    exit 1
fi