#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

config() {
    # Declare gobal ENV vars for setup
    export SETUP_NAME=${1:-"$(basename $THIS_DIR)"}
    export SETUP_PATH=${2:-$THIS_DIR}

    WWW_DIR=${WWW_DIR:-"/usr/share/nginx/html/"}
    CFG_DIR=${CFG_DIR:-"/etc/nginx/conf.d/"}
}

setup() {
    config $@
    
    # Load common setup functions
    source "$THIS_DIR/../utils.sh"
    
    # Install any dependencies used by this service (if not already installed)
    install-dependencies nginx
    
    # Copy template web contents
    if [ -d "$THIS_DIR/www" ]; then
        # Creating sample folder with www content
        sudo rsync -a "$THIS_DIR/www" "$WWW_DIR"
    fi

    # Copy the configurations
    if [ -d "$CFG_DIR" ]; then
        sudo rsync -a "$THIS_DIR/config/" "$CFG_DIR"
    fi

    # Display folder details
    echo "Current nginx details:"
    echo " - Website Dir: $WWW_DIR"
    echo " - Config Path: $CFG_DIR"
    echo "Reloading nginx..."

    sudo systemctl reload nginx
}

setup $@ # <-- Bootstrap the script