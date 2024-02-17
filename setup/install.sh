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

config() {
    # Set the core installation config settings
    APP_BOOT="/boot"                # Default location to look for installation files
    APP_USER=${APP_USER:-$USER}     # The user associated with the system process
    APP_REPO="https://github.com/JohnnyBeProgramming/pi-zero.git"
    
    if [ -f "${BASH_SOURCE:-}" ]; then
        # Resolve the current script folder
        THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
        THIS_FILE=$(basename "${BASH_SOURCE[0]}")
    else
        THIS_DIR="$HOME/setup"
        THIS_FILE="run.sh"
    fi
}

main() {
    # Setup basic config and check for an active internet connection
    config $@
    colors
    check-deps
    
    # Install and upgrade specified packages and services
    #update-os
    install-packages
    install-services
}

check-deps() {
    # Do some pre-checks to ensure we have internet and a valid architecture
    check-arch || fail "Architecture $OSTYPE ($(uname -m)) not supported"
    check-setup-media || fail "Setup failed to find installation media in:\n - $THIS_DIR"    
}

check-arch() {
    # Make sure we are running debian
    [ -f "/etc/debian_version" ] || return 1
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
    local config="$THIS_DIR/packages.ini"
    if [ -f "$config" ]; then
        echo "${reset}${bold}Checking packages...${reset}"
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
                # Upgrade current version
                prefix="${dim}[ ${blue}⇊${dim} ]${reset}"
                label="${bold}${blue}${name}${reset}"
                version="${blue}($found -> $tags)${reset}"
                upgrade=true
            elif [ -z "${found:-}" ]; then
                # Installs missing package
                [ ! "$tags" == "*" ] || tags="latest"
                label="${bold}${green}${name}${reset}"
                version="${dim}(${green}$tags${dim})${reset}"
                upgrade=true
            else
                # Package found locally
                prefix="${dim}[ ${green}✔${dim} ]${reset}"
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
    local config="$THIS_DIR/services.ini"
    if [ -f "$config" ]; then
        echo "${bold}Checking services...${reset}"
        cat $config | sed -e 's/[[:space:]]*#.*// ; /^[[:space:]]*$/d' | while IFS= read -r line; do
            local name=$(echo "$line" | cut -d '=' -f1)
            local enable=$(echo "$line" | cut -d '=' -f2)
            local prefix="${dim}[ ${dim}-${dim} ]${reset}"
            local label="${dim}${name}${reset}"
            local status="${dim}(${enable})${reset}"

            # If this is a cust defined service, (re)create the service
            local service_path="$THIS_DIR/services/$name"
            if [ -d "$service_path" ]
            then
                install-custom-service "$name" "$service_path"
            fi

            # Check if service is installed and it's status
            local found=$(systemctl is-enabled $name 2> /dev/null)
            local old=$([ "${found:-}" == "enabled" ] && echo ON)
            local new=$([ "${enable:-}" == "true" ] && echo ON)            
            local action=""
            if [ -z "${found:-}" ]; then
                # Service not found...
                prefix="${dim}[ ✘ ]${reset}"
                status="${dim}(not installed)${reset}"
                label="${dim}${name}${reset}"
            elif [ ! -z "${old:-}" ] && [ ! -z "${new:-}" ]; then
                # Service running and up to date
                prefix="${dim}[ ${green}✔${dim} ]${reset}"
                label="${bold}${name}${reset}"
                status="${dim}(${green}running${dim})${reset}"
            elif [ ! -z "${old:-}" ] && [ -z "${new:-}" ]; then
                # Service should be disabled
                prefix="${dim}[ ${blue}■${dim} ]${reset}"
                label="${bold}${blue}${name}${reset}"
                status="${dim}(${blue}stopping${dim})${reset}"
                action="disable"
            elif [ -z "${old:-}" ] && [ ! -z "${new:-}" ]; then
                # Service needs to be started
                prefix="${dim}[ ${green}▶${dim} ]${reset}"
                label="${bold}${green}${name}${reset}"
                status="${dim}(${green}starting${dim})${reset}"
                action="enable"
            else
                # Unknown status or already disabled
                prefix="${dim}[ ${dim}■${dim} ]${reset}"
                status="${dim}(${found:-})${reset}"
            fi

            echo "${prefix} ${label} ${status} ${reset}"

            if [ ! -z "${action:-}" ]; then
                sudo systemctl $action $name || fail "Failed to ${action} service: $name"
            fi
        done
    fi
}

install-custom-service() {
    local name=$1
    local path=$2

    # Check if there is a setup script
    if [ -f "$path/setup.sh" ] 
    then
        printf "${dim}"
        . "$path/setup.sh" "$name" "$path"
        printf "${reset}"
    fi


}

fail() {
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
    reset=$([ -z $TERM ] || printf "\e[0m")
    href=$([ -z $TERM ] || printf "\033[04;34m")
}

# Bootstrap the script
main $@