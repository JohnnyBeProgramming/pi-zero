#!/usr/bin/env bash
# --------------------------------------------------------------
# Common service setup functions and utils. Include in scripts:
#  - eg: source "$THIS_DIR/../common.sh"
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------

install-dependencies() {
    local install=()
    for pkg in "$@"; do
        # Check if each provided dependency is installed
        if [ -z "$(apt show $pkg 2> /dev/null | grep "Version: " | cut -d ':' -f2- | tr -d ' ' || true)" ]; then
            install+=($pkg)
        fi
    done
    
    # Install missing packages (if needed)
    if [ ! -z "${install:-}" ]; then
        echo "Installing packages: '${install:-}'"
        sudo apt install -y ${install:-}
    fi
}

install-service() {
    local name=$1
    local dest=$2
    
    if up-to-date $dest; then
        return 0; # Service is up to date
    fi
    
    # Backup current service (if installed), otherwise create folder
    [ ! -d "$dest" ] && mkdir -p "$dest" || setup-backup $dest
    
    # Install the service files and configuration
    setup-service $name "$dest"
    setup-register $name "$dest"
}

up-to-date() {
    local dest=$1
    
    # TODO: Check if the service is already up to date
    #if [ -f "$dest/.checksum" ] && [ -f "$SETUP_PATH/.checksum" ]; then
    #    ...
    #fi
    
    return 1
}

setup-service() {
    local name=$1
    local path=$2
    # Temporarily stop the service while we install
    if [ "$(systemctl is-enabled $name 2> /dev/null)" == "enabled" ]; then
        echo "Stopping service: $name ..."
        sudo systemctl disable $name.service
    fi
    
    # Copy the latest service files to the destination folder
    echo "Updating service: $name ..."
    rsync -a "$path/" "$dest"    
    setup-config $name "$dest"
}

setup-config() {
    local name=$1
    local dest=$2
    
    # Generate manifest and config from templates (if provided)
    export APP_NAME=$name
    export APP_HOME=$APP_HOME
    if [ -f "$dest/service.cfg.tpl" ]; then
        cat "$dest/service.cfg.tpl" | envsubst > "$dest/service.cfg"
    fi
    if [ -f "$dest/service.env.tpl" ]; then
        cat "$dest/service.env.tpl" | envsubst > "$dest/service.env"
    fi
}

setup-register() {
    local name=$1
    local dest=$2
    
    # Install the service manifest into systemd
    if [ -f "$dest/service.cfg" ]; then
        sudo cp -f "$dest/service.cfg" "/etc/systemd/system/$name.service"
    else
        echo "Warning: Service not installed. Config not found '$dest/service.cfg', skipping..."
        return 0
    fi
    
    # Create systemd service for startup and persistence
    if [ -f "/etc/systemd/system/$name.service" ]; then
        echo "Starting service: $name ..."
        sudo systemctl enable $name.service
        sudo systemctl start $name.service
        #journalctl -u $name -e
    fi
}

setup-backup() {
    local dest=$1
    
    # Make a backup of current folder
    echo "Backup existing: $dest"
    cd "$dest" && tar -zcf $dest.tar.gz . && cd - > /dev/null
    
    # TODO: Trap and restore if fail...
    # tar -xvf "$dest.tar.gz" --directory "$dest"
}