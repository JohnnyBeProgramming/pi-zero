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
    BOOT_DIR=${1:-}
    
    if [ -z "${1:-}" ]; then
        echo "Please specify the volume to update."
        echo "eg: $0 /Volumes/bootfs"
        echo 
        echo Hint: diskutil list external
        exit 1
    fi
}

main() {
    # Setup basic config and check for an active internet connection
    config $@
    
    # Configure volume
    copy-setup
    #update-config
    #update-commands
    
    echo "Image updated."
}

copy-setup() {
    if [ -d "$BOOT_DIR/setup" ]; then
        rm -rf "$BOOT_DIR/setup"
    fi

    echo "Copying setup to: $BOOT_DIR"
    rsync -a "$THIS_DIR/" "$BOOT_DIR/setup"
}

update-config() {
    file="$BOOT_DIR/config.txt"

    [ -f "$file" ] || return 0
    [ -f "$file.bak" ] || cat $file > $file.bak
    
    if cat $file | grep "dtoverlay=dwc2" > /dev/null; then
        # Already up to date
        return 0
    fi
    
    if cat $file | grep "dtoverlay=" > /dev/null
    then
        echo " + $file: dtoverlay=dwc2"
        sed -i '' 's|dtoverlay=.*|dtoverlay=dwc2|' $file
    fi
}

update-commands() {
    file="$BOOT_DIR/cmdline.txt"

    [ -f "$file" ] || return 0
    [ -f "$file.bak" ] || cat $file > $file.bak
    
    if cat $file | grep "modules-load=dwc2,g_ether" > /dev/null; then
        # Already up to date
        return 0
    fi
    
    # Add additional modules to command line at startup
    echo " + $file - modules-load=dwc2,g_ether"
    sed -i '' 's|rootwait|rootwait modules-load=dwc2,g_ether|' $file
}

# Bootstrap the script
main $@