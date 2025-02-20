#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
: "${USER_NAME:=`getent passwd 1000 | cut -d: -f1`}"
: "${USER_HOME:=`getent passwd 1000 | cut -d: -f6`}"

# Check if th script should run
[ ! "${USER_NAME:-}" == "" ] || exit 0
[ ! "${USER_HOME:-}" == "" ] || exit 0

# Enable ssh
systemctl enable ssh