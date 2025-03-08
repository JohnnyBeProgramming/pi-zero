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
    colors

    # Resolve the current script folder
    THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
    THIS_FILE=$(basename "${BASH_SOURCE[0]}")

    # Load setup config values (if exists)
    [ ! -f "$THIS_DIR/setup.env" ] || source "$THIS_DIR/setup.env"

    export DEBIAN_FRONTEND=noninteractive
}

main() {
    # Setup basic config and check for an active internet connection
    config $@    
    check-deps
    
    # Install and upgrade specified packages and services
    update-os
    install
}

check-deps() {
    # Do some pre-checks to ensure we have internet and a valid architecture
    
    # Make sure we are running debian
    [ -f "/etc/debian_version" ] \
    || fail "Architecture $OSTYPE ($(uname -m)) not supported"
    
    # Make sure we can access the setup media
    [ -d "$THIS_DIR" ] \
    || fail "Setup failed to find installation media in:\n - $THIS_DIR"    
}

update-os() {
    local last_updated="$THIS_DIR/.last_updated"

    # Update only once a day
    if [ ! -f "$last_updated" ] || [ "$(date '+%Y-%m-%d')" != "$(cat "$last_updated")" ]; then
        # Update system packages
        sudo apt update -y
        sudo apt full-upgrade -y
        sudo apt autoremove -y

        # Track last successfull update
        date '+%Y-%m-%d' > "$last_updated"
    fi
}

install() {    
    install-tools
    #install-packages
    #install-services
}

install-tools() {
    [ ! -z "${SETUP_TOOLS:-}" ] || return 0

    echo "Installing tools and utilities..."
    for tool in "${SETUP_TOOLS[@]}"; do
        # Check if a version was specified
        local version="" # defaults to
        if [[ "$tool" =~ "=" ]]; then
            version=$(echo "$tool" | cut -d '=' -f2)
            tool=$(echo "$tool" | cut -d '=' -f1)
        fi

        # Skip if tool is already installed
        if which $tool > /dev/null; then
            continue
        fi

        # Install the specified tool
        echo " - $tool $([ -z "${version:-}" ] || echo "($version)")"
        if [ -f "$THIS_DIR/tools/$tool.sh" ]; then
            # Install using a custom script
            version="${version:-}" "$THIS_DIR/tools/$tool.sh"
        else
            # Use the default package manager
            sudo apt-get install $tool -y
        fi
    done
    echo "Tools installed."
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
                found=$(dpkg -s $name 2> /dev/null | grep Version | cut -d ' ' -f2 || true)
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
    local services="$THIS_DIR/services"
    if [ -f "$config" ]; then
        echo "${reset}${bold}Checking services...${reset}"
        cat $config | sed -e 's/[[:space:]]*#.*// ; /^[[:space:]]*$/d' | while IFS= read -r line; do
            local name=$(echo "$line" | cut -d '=' -f1)
            local enable=$(echo "$line" | cut -d '=' -f2)
            local prefix="${dim}[ ${dim}-${dim} ]${reset}"
            local label="${dim}${name}${reset}"
            local status="${dim}(${enable})${reset}"            

            # Check if service is installed and it's status
            local found=$(systemctl is-enabled $name 2> /dev/null)
            local old=$([ "${found:-}" == "enabled" ] && echo ON)
            local new=$([ "${enable:-}" == "true" ] && echo ON)            
            local action=""

            # If this is a cust defined service, (re)create the service
            local service_path="$services/$name"
            if [ -d "$service_path" ] && [ "${old:-}" != "ON" ]; then
                install-custom-service "$name" "$service_path"
            fi

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