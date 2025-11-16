#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
: "${CURRENT_HOSTNAME:=`cat /etc/hostname | tr -d " \t\n\r"`}"
: "${SETUP_NETWORK_HOSTNAME:=""}"

# Check if th script should run
[ ! "${CURRENT_HOSTNAME:-}" == "" ] || exit 0
[ ! "${SETUP_NETWORK_HOSTNAME:-}" == "" ] || exit 0

echo "Setting hostname to '$SETUP_NETWORK_HOSTNAME'..."

# Change the hostname
echo "$SETUP_NETWORK_HOSTNAME" > /etc/hostname
sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$SETUP_NETWORK_HOSTNAME/g" /etc/hosts
