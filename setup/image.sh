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

help() {
    echo "Utilities for managing SD Card images for a Raspberry Pi"
    echo ""
    echo "Basic Usage:"
    echo "  $0 ${1:-ACTION} /path/to/volume"
    echo ""
    echo "Actions:"
    echo "  list        List connected external drives"
    echo "  setup       Copy setup folder to installation media"
    echo "  backup      Backup the target SD card a an disk image"
    echo "  restore     Restores an image and burn it to an SD card"
    echo "  convert     Convert an image into a VM boot disk."
    echo "  bootloader  Modify the boot image for the Raspberry Pi"
    echo
}

config() {
    # Set the core installation config settings
    ACTION=${1:-}
    
    # Action is required
    [ ! -z "${ACTION:-}" ] || (help && exit 1)
}

main() {
    # Setup basic config and check for an active internet connection
    config $@
    
    # Configure volume
    shift # past the first arg
    case ${ACTION:-} in
        list)
            # List external volumes that are attacked
            diskutil list external | grep "(external, " | cut -d ' ' -f1
        ;;
        https://**)
            # Pull image directly from an URL, and install add-ons on top of it
            image-from-url $ACTION
        ;;
        latest)
            # Base off latest known release version
            image-from-url "https://downloads.raspberrypi.com/raspios_armhf/images/raspios_armhf-2023-12-06/2023-12-05-raspios-bookworm-armhf.img.xz"
        ;;
        stable)
            # Base off stable version
            image-from-url "https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2017-04-10/2017-04-10-raspbian-jessie-lite.zip"
        ;;
        burn)
            # Copy setup folder to installation media
            image-from-base $@
        ;;
        setup)
            # Copy setup folder to installation media
            image-setup $@
        ;;
        backup)
            # Backup the target SD card a an disk image
            image-backup $@
        ;;
        restore)
            # Restores an image and burn it to an SD card
            image-restore $@
        ;;
        convert)
            # Convert an image into a VM boot disk.
            image-convert $@
        ;;
        bootloader)
            # Modify the boot image for the Raspberry Pi
            image-bootloader $@
        ;;
        *)
            if [ -f "images/${ACTION:-}.img" ]; then
                image-from-base "images/${ACTION:-}.img"
            else
                printf "Action '${ACTION:-}' is unknown or not specified.\n\n"
                help && exit 1
            fi
        ;;
    esac
}

image-from-url() {
    local url=$1
    local file="images/$(basename $1)"
    local name=$(basename ${file%.*})
    local img="$name.img"
    local src="$(basename $(dirname $1))/$name.img"

    if [ ! -f $file ]; then
        echo "Downloading [ $name ]: $url"
        curl $url -o $file
        tar -zxvf $file -C ./images "$img"
    fi

    image-from-base ./images/$img
}

image-from-base() {
    local file=$1
    local volume=${2:-$(select-disk)}
    local path=$(select-volume $volume)
    
    # Rebase the setup from abase image
    image-restore $file $volume
    image-setup $path
    image-bootloader $path
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
image-setup() {
    local volume=${1:-}
    local src="$THIS_DIR/"
    local dest="$volume/setup"
    
    [ ! -z "${volume:-}" ] || fatal "Please specify the volume to update to."
    [ ! -d "$volume/setup" ] || rm -rf "$volume/setup"
    
    echo "Copying setup to: $volume/setup"
    rsync -av "$THIS_DIR/" "$volume/setup"
    echo "Image updated."
}

image-backup() {
    local volume=${1:-$(select-disk)}
    local filename=${2:-"images/$(basename $volume).img"}
    
    mkdir -p "$(dirname $filename)"
    
    # Make a clone of the specified drive
    if which dd > /dev/null
    then
        echo "Creating a new backup:"
        echo " - Volume: $volume"
        echo " - Target: $filename"
        echo "This might take a while..."
        sudo dd if=$volume of=$filename || fatal "Failed to backup image."
        echo "Done."
    else
        echo "Cannot find disk utility 'dd' on local machine"
        exit 1
    fi
}

image-restore() {
    local filename=${1:-}
    [ ! -z "${filename:-}" ] || fatal "Please specify image file to restore"
    [ -f "${filename:-}" ] || fatal "File '$filename' does not exists."

    local volume=${2:-$(select-disk)}
    [ ! -z "${volume:-}" ] || fatal "Please specify the volume to restore to."
    
    # Make a clone of the specified drive
    if which dd > /dev/null
    then
        sudo diskutil unmountDisk $volume
        echo "Restoring disk image:"
        echo " - Source: $filename"
        echo " - Volume: $volume"
        echo "This might take a while..."
        sudo dd if=$filename of=$volume || fatal "Failed to restore image."
        sudo diskutil mountDisk $volume
        echo "Done."
    else
        fatal "Cannot find disk utility 'dd' on local machine"
    fi
}

image-convert() {
    local filename=$1
    
    # Make sure file and target volume exists
    [ -f "$filename" ] || fatal "File '$filename' does not exists."
    
    # Convert to image for QEMU (UTM) virtualisation
    if which qemu-img > /dev/null
    then
        echo "Converting to a VM image: $filename.qcow2"
        qemu-img convert -f raw -O qcow2 $filename $filename.qcow2
    else
        fatal "Package 'qemu-img' not installed."
    fi
}

image-bootloader() {
    local volume=${1:-}
    
    [ ! -z "${volume:-}" ] || fatal "Please specify the volume to restore to."
    
    echo "Updating bootloader: $volume"
    image-boot-config "$volume"
    image-boot-commands "$volume"
    touch "$volume/ssh"
    echo "Done."
}

image-boot-config() {
    local volume=$1
    local file="$volume/config.txt"
    
    [ -f "$file" ] || return 0
    [ -f "$file.bak" ] || cat $file > $file.bak
    
    if cat $file | grep "dtoverlay=dwc2" > /dev/null; then
        # Already up to date
        return 0
    fi
    
    if ! cat $file | grep "dtoverlay=dwc2" > /dev/null; then
        echo " + Config: dtoverlay=dwc2"
        echo "dtoverlay=dwc2" >> $file
    fi
}

image-boot-commands() {
    local volume=$1
    local file="$volume/cmdline.txt"
    
    [ -f "$file" ] || return 0
    [ -f "$file.bak" ] || cat $file > $file.bak
    
    if cat $file | grep "modules-load=dwc2,g_ether" > /dev/null; then
        # Already up to date
        return 0
    fi
    
    # Add additional modules to command line at startup
    echo " + Loads: modules-load=dwc2,g_ether"
    sed -i '' 's|rootwait|rootwait modules-load=dwc2,g_ether|' $file
}

select-disk() {
    local value=""
    n=""
    while true; do
        list=()
        i=0
        printf "External Storage devices:\n\n" 1>&2
        while IFS= read -r line; do
            export i=$(($i+1))
            list+=("$line")
            echo "$i) $line" 1>&2
        done <<< $(diskutil list external | grep "(external, " | cut -d ' ' -f1 )
        [ "$i" != "0" ] || throw "No storage devices detected."

        printf "\n" 1>&2
        read -p 'Select target storage: ' n

        # If $n is an integer between one and $count...
        if [[ "$n" -eq "$n" ]] && [[ "$n" -gt 0 ]] && [[ "$n" -le "$i" ]]; then
            echo "${list[$(($n-1))]}"
            break
        fi
    done
}

select-volume() {
    mount | grep $1 | cut -d ' ' -f3
}


fatal() {
    red=$([ -z $TERM ] || printf "\033[0;31m")
    reset=$([ -z $TERM ] || printf "\e[0m")
    printf "${red:-}$1${reset:-}\n"
    exit 1
}

# Bootstrap the script
main $@