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
    APP_NAME="opsec"                # Name of the application that will be installed
    APP_BOOT="/boot"                # Default location to look for installation files
    APP_USER=${USER:-$APP_NAME}     # The user associated with the system process
    APP_HOME="${HOME}/app"          # Default installation target folder
    APP_REPO="https://github.com/JohnnyBeProgramming/pi-zero.git"    
}

main() {
    # Setup basic config and check for an active internet connection
    config $@
    
    # Do some pre-checks to ensure we have internet and a valid architecture
    check-arch || fail "Architecture $OSTYPE ($(uname -m)) not supported"
    check-internet || fail "No internet connection could be established."
    
    # Update operating system packages to their latest versions
    update-os
    
    # Setup defaults
    setup-features
}

check-arch() {
    # Make sure we are running debian
    [ -f "/etc/debian_version" ] || return 1
}

check-internet() {
    TEST_URL="http://www.msftncsi.com/ncsi.txt"
    TEST_VAL="Microsoft NCSI"
    echo "Testing internet connection & DNS resolution..."
    echo "[?] curl -s $TEST_URL == '$TEST_VAL'"
    TEST_RES=$(curl -s $TEST_URL)
    if [ ! "$TEST_VAL" == "$TEST_RES" ]; then
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

setup-features() {
    echo "TODO: Setup additional features..."
}

fail() {
    local red=$([ -z $TERM ] || printf "\033[0;31m")
    local reset=$([ -z $TERM ] || printf "\033[0m")
    printf "${red}FAIL: $1\n${reset}"
    exit 1
}

# Bootstrap the script
main $@