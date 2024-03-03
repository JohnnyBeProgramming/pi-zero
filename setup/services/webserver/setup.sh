#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

config() {
    # Declare gobal ENV vars for setup
    export SETUP_NAME=${1:-"$(basename $THIS_DIR)"}
    export SETUP_PATH=${2:-$THIS_DIR}

    WWW_DIR=${WWW_DIR:-"$THIS_DIR/www"}
}

setup() {
    config $@
    
    # Load common setup functions
    source "$THIS_DIR/../utils.sh"
    
    # Install any dependencies used by this service (if not already installed)
    install-dependencies nginx
    
    # Copy template web contents (if needed)
    [ -d "$WWW_DIR" ] || mkdir -p "$WWW_DIR"
    [ -d "/www" ] || cp -rf "$WWW_DIR" /www

    # Adjust the Firewall if needed
    echo "TODO: ..."
    echo sudo ufw status #| grep 'Nginx HTTP'
    echo sudo ufw allow 'Nginx HTTP'

    systemctl status nginx
    #sudo systemctl reload nginx
}

setup $@ # <-- Bootstrap the script