#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------

# Check if th script should run
[ ! "${SETUP_NETWORK_SSH_ENABLE:-false}" == "true" ] || exit 0

echo "Enabling SSH (if not already enabled)..."

# Enable ssh
systemctl enable ssh
systemctl start ssh