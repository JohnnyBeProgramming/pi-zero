#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
# This script is used to initialise a (Debian) rasberry pi device,
# and installs the following:
#  - Latest system updates and patches
#  - Enables SSH for remote connections (if not already done)
#  - Developer tools such as python, node, golang and rust
#  - Some tools used for network mapping and DNS lookup
#  - Software to turn the device into an access point
# --------------------------------------------------------------
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
THIS_FILE=$(basename "${BASH_SOURCE[0]}")

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
    check-deps
    
    # Update operating system packages to their latest versions
    #update-os
    
    # Setup defaults
    install-packages
    install-services
}

check-deps() {
    # Do some pre-checks to ensure we have internet and a valid architecture
    #check-arch || fail "Architecture $OSTYPE ($(uname -m)) not supported"
    #check-internet || fail "No internet connection could be established."
    check-setup-media || fail "Setup failed to find installation media in:\n - $THIS_DIR"
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

check-setup-media() {
    if [ ! -f "$THIS_DIR/$THIS_FILE" ]
    then
        return 1
    fi
}

update-os() {
    # Update system packages
    sudo apt update
    sudo apt full-upgrade -y
}

install-packages() {
    colors

    local config="$THIS_DIR/setup.ini"    
    if [ -f "$config" ]; then
        echo "${bold}Installing additional packages...${reset}"
        cat $config | sed -e 's/[[:space:]]*#.*// ; /^[[:space:]]*$/d' | while IFS= read -r line; do
            local name=$(echo "$line" | cut -d '=' -f1)
            local tags=$(echo "$line" | cut -d '=' -f2)
            local prefix="${dim}[ ${dim}-${dim} ]${reset}"
            local label="${bold}${name}${reset}"
            local version="${dim}(${tags})${reset}"
            local upgrade=false

            # Check if the package is installed and up to date            
            if [ "$tags" == "*" ] && [ ! -z "$(which $name)" ]; then
                # Up to date...
                prefix="${dim}[ ${green}✔${dim} ]${reset}"
                version="${dim}(any)${reset}"
                found="*"
            else
                # Try and find current package version
                found=$(apt show $name 2> /dev/null | grep "Version: " | cut -d ':' -f2- | tr -d ' ' || true)
                version="${dim}($found)${reset}"
            fi

            # Check if we need to upgrade
            if [ ! -z "${found:-}" ] && [[ "$found" < "$tags" ]]
            then
                prefix="${dim}[ ${blue}⇊${dim} ]${reset}"
                label="${bold}${blue}${name}${reset}"
                version="${blue}($found -> $tags)${reset}"
                upgrade=true
            elif [ -z "${found:-}" ]; then
                [ ! "$tags" == "*" ] || tags="latest"
                label="${bold}${green}${name}${reset}"
                version="${dim}(${green}$tags${dim})${reset}"
                upgrade=true
            fi

            # Print package and its current state
            printf "${prefix} ${label} ${version} "

            # Upgrade package (if needed)
            if $upgrade; then
                printf "${dim}...${dim}\n"
                if ! upgrade-package $name "$version"; then
                    # Check for failures after upgrade
                    prefix="${dim}[ ${red}✘${dim} ]${reset}"
                    label="${bold}${red}${name}${reset}"
                    printf "${prefix} ${label} [ ${red}${bold}FAILED${dim} ]${reset}\n"
                    exit 1
                fi
            else
                # Everything is up to date
                printf "\n"
            fi
        done
    fi
}

upgrade-package() {
    local name=$1
    local tags=${2:-}

    if [ -f "$THIS_DIR/packages/$name.sh" ]; then
        # Run the included setup script
        bash "$THIS_DIR/packages/$name.sh" || return 1
    else
        # Install using package manager
        sudo apt-get -y install $name || return 1
    fi

    # Reset color in terminal to normal
    printf "${reset}"     
}

install-services() {
    colors

    local config="$THIS_DIR/services.ini"
    if [ -f "$config" ]; then
        echo "${bold}Installing additional services...${reset}"
        cat $config | sed -e 's/[[:space:]]*#.*// ; /^[[:space:]]*$/d' | while IFS= read -r line; do
            local name=$(echo "$line" | cut -d '=' -f1)
            local tags=$(echo "$line" | cut -d '=' -f2)
            local prefix="${dim}[ ${green}✔${dim} ]${reset}"
            local label="${bold}${name}${reset}"
            local version="${dim}(${tags})${reset}"
            echo "${prefix} ${label} ${version} ${reset}"
        done
    fi
}

fail() {
    colors
    printf "${red}FAIL: $1\n${reset}"
    exit 1
}

colors() {
    bold=$([ -z $TERM ] || printf "\033[1m")
    dim=$([ -z $TERM ] || printf "\033[0;90m")
    white=$([ -z $TERM ] || printf "\033[0;97m")
    red=$([ -z $TERM ] || printf "\033[0;31m")
    blue=$([ -z $TERM ] || printf "\033[0;34m")
    green=$([ -z $TERM ] || printf "\033[0;32m")
    yellow=$([ -z $TERM ] || printf "\033[0;33m")
    reset=$([ -z $TERM ] || printf "\033[0m")
}

# Bootstrap the script
main $@