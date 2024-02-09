#!/bin/sh
# --------------------------------------------------------------------
# Simple debug script to check service status
# --------------------------------------------------------------------
APP_NAME="opsec"
APP_HOME="$HOME/app"

# List all system services
systemctl --type=service

# Show boot logs
#journalctl -b

# Show the service logs
journalctl -u "$APP_NAME.service"