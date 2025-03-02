#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------

# Check if th script should run
[ ! "${SSH_ENABLE:-false}" == "true" ] || exit 0

echo "Enabling SSH (if not already enabled)..."

# Enable ssh
systemctl enable ssh
