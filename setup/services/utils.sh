#!/usr/bin/env bash
# --------------------------------------------------------------
# Common services setup functions and utils. Include in scripts:
#  - eg: source "$THIS_DIR/../utils.sh"
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------

check-internet() {
    TEST_URL="http://www.msftncsi.com/ncsi.txt"
    TEST_VAL="Microsoft NCSI"
    printf "${white}${bold}Testing internet connection & DNS resolution...${reset}\n"
    printf "${dim}[ ${blue}?${dim} ] curl -s ${href}$TEST_URL${dim} == ${white}'$TEST_VAL'${dim}${reset}\n"
    TEST_RES=$(curl -s $TEST_URL)
    if [ "$TEST_VAL" == "$TEST_RES" ]; then
        echo "${dim}[ ${green}✔${dim} ] Connection established from: ${href}$(hostname)${reset}"
        return 0
    else
        printf "${bold}${red}[ ! ] Error: No Internet connection, or name resolution doesn't work!${reset}\n"
        echo "----------------------------------------"
        echo "TEST_URL: $TEST_URL"
        echo "TEST_VAL: $TEST_VAL (expected)"
        echo "TEST_RES: $TEST_RES"
        echo "----------------------------------------"
        return 1
    fi    
}

install-dependencies() {
    local install=""
    for pkg in "$@"; do
        # Check if each provided dependency is installed
        if ! dpkg -l $pkg 2> /dev/null > /dev/null; then
            install+="$pkg "
        fi
    done
    
    # Install missing packages (if needed)
    if [ ! -z "${install:-}" ]; then
        echo "Installing packages: ${install:-}"
        sudo apt install -y ${install:-}
    fi
}

install-service() {
    local name=$1
    local dest=$2
    
    if up-to-date $dest; then
        return 0; # Service is up to date
    fi

    printf "${dim}[ ${blue}i${dim} ] ${white}${bold}$name ${reset}${dim}(${blue}installing${dim})${reset}${dim}\n"
    
    # Backup current service (if installed), otherwise create folder
    [ ! -d "$dest" ] && mkdir -p "$dest" || setup-backup $dest
    
    # Install the service files and configuration
    setup-service $name "$dest"
    setup-register $name "$dest"
}

up-to-date() {
    local dest=$1
    local path=$SETUP_PATH
    local changes=$(rsync -aEim --dry-run "$path/" "$dest" | wc -l)
    
    # Check if there are any changes that needs to be copied
    if [[ "${changes:-0}" -gt "1" ]]; then
        return 1
    fi
    
    # Changes detected
    return 0
}

setup-service() {
    local name=$1
    local dest=$2
    local path="$SETUP_PATH"

    # Temporarily stop the service while we install
    if [ "$(systemctl is-enabled $name 2> /dev/null)" == "enabled" ]; then
        echo "Stopping '$name' service..."
        sudo systemctl disable $name.service
    fi
    
    # Copy the latest service files to the destination folder
    echo "Updating '$name' service..."    
    rsync -a "$path/" "$dest"    
    setup-config $name "$dest"
}

setup-config() {
    local name=$1
    local dest=$2
    
    # Generate manifest and config from templates (if provided)
    export APP_NAME=$name
    export APP_HOME=$dest
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
        echo "Starting '$name' service..."
        sudo systemctl enable $name.service
        sudo systemctl start $name.service
        #journalctl -u $name -e
    fi
}

setup-backup() {
    local dest=$1
    
    # Make a backup of current folder
    echo "Backing up: $dest"
    cd "$dest" && tar -zcf $dest.tar.gz . && cd - > /dev/null
    
    # TODO: Trap and restore if fail...
    # tar -xvf "$dest.tar.gz" --directory "$dest"
}
