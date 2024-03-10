#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

config() {
    # Declare gobal ENV vars for setup
    export SETUP_NAME=${1:-"$(basename $THIS_DIR)"}
    export SETUP_PATH=${2:-$THIS_DIR}    

    # Load the go path that is stored in the profile
    [ ! -f ~/.profile ] || source ~/.profile
}

setup() {
    config $@
    
    # Load common setup functions
    source "$THIS_DIR/../utils.sh"
    
    # Install any dependencies used by this service (if not already installed)
    install-dependencies nmap gobuster 
    install-taskfile
    #install-hugo
    #install-rustscan
    
    # Recreate the service manifest and update to latest
    #install-service $SETUP_NAME "$HOME/.services/$SETUP_NAME"
}

install-taskfile() {
    if ! which task > /dev/null; then
        echo "Installing Taskfile..."
        go install github.com/go-task/task/v3/cmd/task@latest
    fi
}

install-rustscan() {
    if ! which rustscan > /dev/null; then
        pushd /tmp > /dev/null
        git clone https://github.com/RustScan/RustScan.git
        cd ./RustScan && cargo build --release
        mv ./target/release/rustscan /usr/local/bin/rustscan
        cd .. && rm -rf ./RustScan
        popd > /dev/null
    fi
}

install-hugo() {
    if ! which hugo > /dev/null; then
        echo "Installing Hugo..."
        CGO_ENABLED=1 go install -tags extended github.com/gohugoio/hugo@latest
    fi
}

setup $@ # <-- Bootstrap the script