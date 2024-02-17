#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
# This script is used to add additional setup scripts to an image
# boot drive for raspberry pi's:
#  - setup/**       # Copies required setup scripts to boot volume
#  - config.txt     # Modifies config file with additional changes
#  - cmdline.txt    # Inject additional modules to run
# --------------------------------------------------------------
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

config() {
    # Set the core installation config settings
    TARGET_HOST=${1:-}
    
    if [ -z "${1:-}" ]; then
        echo "Please specify the ssh user and hostname."
        echo "eg: $0 user@hostname.local"
        exit 1
    fi    

    dim=$([ -z $TERM ] || printf "\033[0;90m")
    reset=$([ -z $TERM ] || printf "\e[0m")
}

main() {
    config $@
    
    # Configure volume
    echo "Copying setup files to $TARGET_HOST"
    printf "${dim:-}"
    tar zcf - ./setup | ssh $TARGET_HOST "tar zxvf - ./setup && ./setup/install.sh"
    printf "${reset:-}"
}

# Bootstrap the script
main $@