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
    install-dependencies git
    
    # Recreate the service manifest and update to latest
    install-service $SETUP_NAME "$HOME/.services/$SETUP_NAME"
}

config() {
    # Declare gobal ENV vars for setup
    export SETUP_NAME=${1:-"$(basename $THIS_DIR)"}
    export SETUP_PATH=${2:-$THIS_DIR}    
}

setup $@ # <-- Bootstrap the script