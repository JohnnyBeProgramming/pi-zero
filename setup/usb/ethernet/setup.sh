#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

setup() {
    config $@
    
    # Load common setup functions
    source "$THIS_DIR/../utils.sh"
    
    # Install any dependencies used by this service (if not already installed)
    #install-dependencies 
    upgrade
    
    # Recreate the service manifest and update to latest
    #install-service $SETUP_NAME "$HOME/.hotspot"
}

config() {
    # Declare gobal ENV vars for setup
    export SETUP_NAME=${1:-"$(basename $THIS_DIR)"}
    export SETUP_PATH=${2:-$THIS_DIR}
}

upgrade() {
    # See also: https://thepi.io/how-to-use-your-raspberry-pi-as-a-wireless-access-point/

    # Create a new USB interface
    if [ ! -f "/etc/network/interfaces.d/usb_interface" ]; then
        echo "Creating USB interfaces: /etc/network/interfaces.d/hotspot"
        sudo cp -f "$THIS_DIR/etc/network/interfaces.d/usb_interface" "/etc/network/interfaces.d/usb_interface"    
    fi

    # AAdd the static IP for the new USB interface
    if ! cat /etc/resolvconf.conf | grep -v '#.*' | grep 'name_servers=' > /dev/null; then
        local STATIC_IP="192.168.2.2"
        echo "Assign static IP: $STATIC_IP"
        echo "name_servers=$STATIC_IP" | sudo tee -a /etc/resolvconf.conf > /dev/null
    fi
    
}

setup $@ # <-- Bootstrap the script