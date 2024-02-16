#!/bin/sh
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
# This script starts a system service rasberry pi device
# --------------------------------------------------------------
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

config() {
    # Load the service config (if present)
    if [ -f "$THIS_DIR/service.env" ]
    then
        echo "Loading config: $THIS_DIR/service.env"
        source $THIS_DIR/service.env
    else
        echo "Warning: No config found at $THIS_DIR/service.env"
    fi

	# Define defaults (if not already set)
	APP_NAME=${APP_NAME:-"unknown"}
	APP_HOME=${APP_HOME:-"$HOME/$APP_NAME"}
}

run() {
	echo "Service starting up..."
    config $@ # Load config settings
	
	# TODO: Add your entrypoint here...
	if wifi-check; then
		echo "Connected via WiFi connection."
	fi
	
	# Post installation advice
	echo "Done. Service is now running and active."
	echo "===================================================================================="
}

wifi-check() {
    if ! iwconfig 2>&1 | grep -q -E ".*wlan0.*"; then
        echo "...[Error] no wlan0 interface found"
        return 1
    fi
    return 0
}

# Bootstrap the script
run $@