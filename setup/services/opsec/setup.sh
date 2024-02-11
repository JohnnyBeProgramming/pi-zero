#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

setup() {
    export SETUP_NAME=${1:-"$(basename $THIS_DIR)"}
    export SETUP_PATH=${2:-$THIS_DIR}

    # Prepare the application folder where the service will be installed
    if [ -z "$APP_HOME" ]; then
        echo "You need to define the \$APP_HOME ENV var."
        echo "Aborting $SETUP_NAME service setup."
        exit 1
    fi

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
        echo "Checking dependencies: ${require:-}"
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
    fi
}

install-service() {
    local dest="$APP_HOME/.services/$SETUP_NAME"
    local state=$(systemctl is-enabled $SETUP_NAME 2> /dev/null)

    # Temporarily stop the service while we install
    if [ "${state:-}" == "enabled" ]; then
        echo "Stopping service: $SETUP_NAME ..."
        sudo systemctl disable $SETUP_NAME.service
    fi

    # Copy the latest service to the app folder
    if [ -d "$dest" ]; then
        # Make a backup of current folder
        echo "Backup existing: $dest"
        cd "$dest" && tar -zcf $dest.tar.gz . && cd - > /dev/null

        # TODO: Trap and restore if fail...        
        # tar -xvf "$dest.tar.gz" --directory "$dest"
    fi

    echo "Updating service: $SETUP_NAME ..."
    mkdir -p "$dest"
    rsync -a "$SETUP_PATH/" "$dest"
    
    # Generate manifest from template if provided
    if [ -f "$dest/service.cfg.tpl" ]; then
        cat "$dest/service.cfg.tpl" | envsubst > "$dest/service.cfg"
    fi

    # Install the service manifest in systemd
    if [ -f "$dest/service.cfg" ]; then
        sudo cp -f "$dest/service.cfg" "/etc/systemd/system/$SETUP_NAME.service"
    else
        echo "Warning: Not found '$dest/service.cfg', skipping..."
        return 0
    fi
    
    # Create systemd service for startup and persistence
    # Note: switched to multi-user.target to make nexmon monitor mode work
    if [ -f "/etc/systemd/system/$SETUP_NAME.service" ]; then
        echo "Starting service: $SETUP_NAME ..."
        sudo systemctl enable $SETUP_NAME.service
        sudo systemctl start $SETUP_NAME.service
    fi        
}

setup $@ # <-- Bootstrap the script