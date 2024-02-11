#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

setup() {
    SETUP_NAME=${1:-"$(basename $THIS_DIR)"}
    SETUP_PATH=${2:-$THIS_DIR}

    # Install any dependencies used by this service (if not already installed)
    install-dependencies

    # Recreate the service manifest and update to latest
    install-service
}

install-dependencies() {
    # nmap:         Nmap ("Network Mapper") is an open source tool for network exploration and security auditing.
    # dirbuster:    DirBuster is a multi threaded java application designed to brute force directories and files names on web/application servers.
    # gobuster:     Discover directories and files that match in the wordlist (written on golang)
    local require=("nmap" "gobuster")
    local install=()

    # Check for installed packages
    if [ ! -z "${require:-}" ]; then
        echo "Checking required dependencies: ${require:-}"
        for pkg in ${require[@]}; do 
            found=$(apt show $pkg 2> /dev/null | grep "Version: " | cut -d ':' -f2- | tr -d ' ' || true)
            if [ -z "${found:-}" ]; then
                install+=($pkg)
            fi
        done
    fi

    # Install missing packages (if needed)
    if [ ! -z "${install:-}" ]; then
        echo "Installing packages: '${install:-}'"
        sudo apt install -y ${install:-}
    else
        echo "Dependencies are up to date."
    fi
}

install-service() {
    echo "TODO: Copy setup scripts to app home:"
    echo " - [ $SETUP_NAME ] $SETUP_PATH -> ${APP_HOME:-}"
    exit 0

    if [ ! -d "$APP_HOME" ]
    then
        # Pull the application sources from git
        git clone $APP_REPO $APP_HOME
    fi
    
    # Create systemd service for startup and persistence
    # Note: switched to multi-user.target to make nexmon monitor mode work
    if [ ! -f /etc/systemd/system/$APP_NAME.service ]; then
        echo "Injecting 'opsec' startup script..."
        cat <<- EOF | sudo tee /etc/systemd/system/$APP_NAME.service > /dev/null
[Unit]
Description=OpSec Startup Service
#After=systemd-modules-load.service
After=local-fs.target
DefaultDependencies=no
Before=sysinit.target

[Service]
#Type=oneshot
Type=forking
RemainAfterExit=yes
ExecStart=/bin/bash $APP_HOME/boot/boot_simple
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
#WantedBy=sysinit.target
EOF
    fi
    
    sudo systemctl enable $APP_NAME.service
}

setup $@ # <-- Bootstrap the script