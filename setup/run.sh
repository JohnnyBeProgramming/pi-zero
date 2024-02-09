#!/usr/bin/env bash
# --------------------------------------------------------------
# This script is used to initialise a (Debian) rasberry pi device,
# and installs the following:
#  - Latest system updates and patches
#  - Enables SSH for remote connections (if not already done)
#  - Developer tools such as python, node, golang and rust
#  - Some tools used for network mapping and DNS lookup
#  - Software to turn the device into an access point
# --------------------------------------------------------------

config() {
    # Set the core installation config settings
    TEST_URL="http://www.msftncsi.com/ncsi.txt"
    TEST_VAL="Microsoft NCSI"
    
    APP_BOOT="/boot"
    APP_NAME="opsec"
    APP_USER=${USER:-$APP_NAME}
    APP_HOME="${HOME}/app"
}

main() {
    # Setup basic config and check for an active internet connection
    config $@
    
    # Check if we have an active internet connection
    if ! check-arch; then
        echo "FATAL: Architecture $OSTYPE ($(uname -m)) not supported"
        exit 1
    fi

    if ! check-internet; then
        # Without internet, we cannot install any additional tools
        echo "FATAL: No internet connection could be established."
        exit 1
    else
        # Update OS packages to their latest versions
        update-os
        
        # Setup defaults
        setup-defaults
    fi
}

check-arch() {
    if [ -f "/etc/debian_version" ]; then
        return 0
    fi
    return 1
}

check-internet() {
    echo "Testing internet connection & DNS resolution..."
    echo "[?] curl -s $TEST_URL == '$TEST_VAL'"
    TEST_RES=$(curl -s $TEST_URL)
    if [ ! "$TEST_VAL" != "$TEST_RES" ]; then
        echo "[!] Error: No Internet connection, or name resolution doesn't work!"
        echo "----------------------------------------"
        echo "TEST_URL: $TEST_URL"
        echo "TEST_VAL: $TEST_VAL (expected)"
        echo "TEST_RES: $TEST_RES"
        echo "----------------------------------------"
        return 1
    fi
    
    echo "[✔] Connection established: $(hostname)"
    return 0
}

update-os() {
    sudo apt update
    sudo apt full-upgrade -y
}

setup-defaults() {
    echo "TODO: Setup additional features..."
}

# Bootstrap the script
main $@