#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
# This script is used to add additional setup scripts to an image
# boot drive for raspberry pi's
# --------------------------------------------------------------
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

help() { 
    cat << EOF
Basic Usage:
  $0 ACTION [ args ]

Actions:
  init
  image <path-to-image-file>
  disk <disk-mount>

Disk Mounts:
$(list-drives | sed 's|^| - |' || echo " - No disks available")

EOF
}

main() {
    ACTION=${1:-}; [ -z "${1:-}" ] || shift;
    config $@ # <-- Parse the command line args
    
    # Process the action that the user specified (if any)
    case ${ACTION:-""} in
        init) setup-init;; # Initialize a raspberry pi environment
        download) download-image "$1" "${2:-"$(basename "$1")"}";; # Download a bootable image
        image) setup-image $@;; # Download and generate a bootable image
        disk) setup-disk $@;; # Burn an image to the SD card mounted as a volume
        boot) setup-boot $@;; # Set the boot modifications for SD card on first use
        vm) setup-vm $@;; # Start a VM for the selected image
        *) help && exit 1;; # Command not found, show help
    esac    
}

config() {
    [ ! -f .env ] || export $(cat .env | xargs) # Load session variables

    # Parse the command line arguments
    POSITIONAL=()
    while [[ $# -gt 0 ]]
    do
        case $1 in
            -h|--help) help && exit 0;;
            -i|--image) SETUP_IMAGE_FILE="$2" && shift && shift;; # past argument and value
            -m|--mount) SETUP_VOLUME_MOUNT="$2" && shift && shift;; # past argument and value
            --dry-run) DRY_RUN=true && shift;;
            *) # unknown option
                POSITIONAL+=("$1") # save it in an array for later
                shift # past argument
            ;;
        esac
    done
    # restore positional parameters that could not be matched and parsed
    set -- "${POSITIONAL[@]:-}"
    
    # Prompt the user for inputs (if not already specified)
    if which gum > /dev/null; then 
        config-interactive # <-- Prompt user for input
    else
        printf "Hint: Install 'gum' for a better interactive command line experience.\n"
    fi    
}

config-interactive() {
    # Set basic styles and formatting
    C_PRIMARY=12
    F_PRIMARY="gum style --foreground $C_PRIMARY"

    export GUM_INPUT_BORDER_FOREGROUND="#F00"
    export GUM_INPUT_CURSOR_FOREGROUND="#0FF"
    export GUM_INPUT_PROMPT_FOREGROUND="#00F"

    # Display the headers for this script
    gum style \
        --border normal \
        --margin "1" \
        --padding "1 2" \
        "`$F_PRIMARY '📦 Raspberry Pi Zero'` - Setup a SD Card image"

    # Select the action (if not already selected)
    : "${ACTION:="$(cat <<- EOF | gum choose --header="Setup action to perform?" --limit 1
init
image
disk
EOF
)"}"
}

setup-image() {
    # Select the disk image file to use when buring the image
    : "${SETUP_IMAGE_FILE:=${1:-"$(prompt-image-file)"}}"
    : "${SETUP_IMAGE_FILE:?"Please specify the image you want to setup."}"

    # Mount image so we can access files within
    mount-image "$SETUP_IMAGE_FILE"

    # Create and initialise the image settings file
    if [ ! -f "$SETUP_MOUNT_BOOT/setup.env" ]; then
        setup-init
    fi

    # Update the image boot partition with our selected features
    [ -z "${SETUP_MOUNT_BOOT:-}" ] || setup-boot "$SETUP_MOUNT_BOOT"

    # Check if we should burn the resulting image
    if gum confirm "Burn image to SD Card?"; then
        # Burn image to SD card
        setup-disk
    else
        # Unmount disk and release sources, as we no longer need it
        hdiutil eject $SETUP_MOUNT_DRIVE
    fi
}

setup-init() {
    # Select the disk image file to use, this will be our main identifier
    : "${SETUP_IMAGE_FILE:=${1:-"$(prompt-image-file)"}}"
    : "${SETUP_IMAGE_FILE:?"Please specify the image you want to setup."}"

    # Mount image so we can access the setup files
    if [ -z "${SETUP_MOUNT_BOOT:-}" ]; then
        mount-image "$SETUP_IMAGE_FILE"
    fi
    # ------------------------------------------------
    # TODO: Remove hard coded path redirect
    TEMP_DIR="./temp/$(basename $SETUP_IMAGE_FILE)"
    mkdir -p "$TEMP_DIR"
    cp -rf "$SETUP_MOUNT_BOOT/" "$TEMP_DIR"
    SETUP_MOUNT_BOOT="$TEMP_DIR"
    # ------------------------------------------------

    # Declare a setup environment file or load current settings
    : "${SETUP_CONFIG_ENV:="$SETUP_MOUNT_BOOT/setup.env"}"
    [ -f "$SETUP_CONFIG_ENV" ] || cp ./default.env "$SETUP_CONFIG_ENV"
    source "$SETUP_CONFIG_ENV"
    
    # Prompt user basic setup information
    setup-admin
    #setup-network
    #setup-tools
    #setup-services  

    # Copy the setup files to the boot folder
    setup-boot "$SETUP_MOUNT_BOOT"
}

setup-admin() {
    setup-ask SETUP_ADMIN_USER "Admin Username"
    setup-ask SETUP_ADMIN_PASS "Admin Password" --password
}

setup-network() {
    if ! setup-confirm SETUP_NETWORK_ENABLED "Connect device to network?"; then
        return 0
    fi

    # Basic network information
    setup-ask SETUP_NETWORK_HOSTNAME    "Network Hostname"
    setup-confirm SETUP_NETWORK_SSH_ENABLE  "Network: Enable SSH?"

    # Wifi settings
    if setup-confirm SETUP_NETWORK_WIFI_ENABLE  "Connect to Wifi network?"; then
        setup-ask SETUP_NETWORK_WIFI_SSID   "Wifi network name"
        setup-ask SETUP_NETWORK_WIFI_PSK    "Wifi network pass key" --password
        setup-ask SETUP_LOCALE_COUNTRY      "Wifi Country"
    fi
}

setup-tools() {
    echo TODO - Tools
    return 0
    # Interactively prompt user to setup features
    local continue="false"
    while [ "$continue" != "true" ]; do
        while read option; do
            case ${option:-"(continue)"} in
                "(continue)") continue="true";; # Initialize a raspberry pi environment
                admin) echo " - TODO Setup $option";; # Download and generate a bootable image
                network) echo " - TODO Setup $option";; # Download and generate a bootable image
                *) echo "Option '$option' not found."
            esac 
        done < <(cat << EOF | gum filter --no-limit --header "Select the addons you want to initialize and include"
(continue)
admin
network
volumes
tools
EOF
)
    done
}

setup-services() {
    echo TODO - Services
}

setup-env() {
    local key="$1"
    local val="$2"

    if [ ! -z "$SETUP_CONFIG_ENV" ]; then
        if grep -E "^$key=" "$SETUP_CONFIG_ENV" > /dev/null; then
            # Update existing entry
            sed -i '' -E "s|^($key)=.*$|\1=\"$val\"|" "$SETUP_CONFIG_ENV"
        else
            # Add new entry to config
            echo "$key=\"$val\"" >> "$SETUP_CONFIG_ENV"
        fi
    fi
}

setup-ask() {
    local key="${1:-}"; [ -z "${1:-}" ] || shift;
    local msg="${1:-}"; [ -z "${1:-}" ] || shift;
    local val="$(eval "echo \$$key")"

    read val < <(
        gum input --header="$msg" --value="${val:-}" $@ \
        || throw "User Canceled"
    )
    
    # Update the setup environment file (if exists)
    [ -z "${key:-}" ] || setup-env "$key" "${val:-}"
}

setup-confirm() {
    local key="${1:-}"; [ -z "${1:-}" ] || shift;
    local msg="${1:-}"; [ -z "${1:-}" ] || shift;
    local val="$(eval < <(echo "\$$key"))"
    echo "\$$key = [$val]" >&2
    read val < <(gum confirm "$msg" --default="${val:-false}" \
        && echo true \
        || echo false
    )

    # Update the setup environment file (if exists)
    [ -z "${key:-}" ] || setup-env "$key" "${val:-}"

    [ "$val" == "true" ] && return 0 || return 1
}

setup-choose() {
    local msg="${1:-}"; [ -z "${1:-}" ] || shift;
    cat /dev/stdin | gum choose --header "$msg" $@
}

setup-disk() {
    : "${SETUP_IMAGE_FILE:=${1:-"$(prompt-image-file)"}}"
    : "${SETUP_VOLUME_MOUNT:=${2:-"$(prompt-volume-mount)"}}"

    [ ! -z "${SETUP_VOLUME_MOUNT:-}" ] || throw "Unknown volume mount: ${SETUP_VOLUME_MOUNT:-}"
    
    # Burn the base image to the SD Card image
    echo "Copying image: $SETUP_IMAGE_FILE > $SETUP_VOLUME_MOUNT"
    copy-image "$SETUP_IMAGE_FILE" "$SETUP_VOLUME_MOUNT"
}

setup-boot() {
    local path=${1:-""}
    local boot="$1"
    local boot_files="./setup/boot"

    # Stop the script here if no boot volume was specified
    [ -d "${path:-}" ] || throw "The boot path '${path:-}' does not exists."
    
    echo "Updating SD Card boot: $path"

    # Copy pre-defined boot files
    if [ -d "$boot_files" ]; then        
        cp -rf "$boot_files/" "$path"
    fi

    # Configure the first run script
    setup-cmdline-apply "system.run=/boot/setup.sh"
    setup-cmdline-apply "system.run_success_action=reboot"
    #setup-boot-cmdline "cmdline.txt" "{ unit: kernel-command-line.target }"

    # Configure ethernet over USB cable (if enabled)
    if [ "${SETUP_NETWORK_USB_ENABLED:-}" == "true" ]; then
        #setup-config-apply "dtoverlay=dwc2"
        setup-cmdline-apply "modules-load=dwc2,g_ether" "rootwait"
    fi

    # Configure SSH access (if enabled)
    if [ "${SETUP_NETWORK_SSH_ENABLED:-}" == "true" ]; then
        echo "" | setup-boot-overlay "ssh.txt"
    fi

    # There is a caveat with doing this. It makes using two ethernet or wifi devices difficult if not impossible.
    #setup-boot-cmdline "cmdline.txt" "{ net.ifnames: '0' }"
    # ---------------------------------------    
}

setup-vm() {
    # Select the disk image file to use when buring the image
    : "${SETUP_IMAGE_FILE:=${1:-"$(prompt-image-file)"}}"
    : "${SETUP_IMAGE_FILE:?"Please specify the image you want to setup."}"

    # Mount image so we can access files within
    mount-image "$SETUP_IMAGE_FILE"

    # Create and initialise the image settings file
    echo "Image volumes mounted:"
    echo " - boot: $SETUP_MOUNT_BOOT"
    echo " - disk: $SETUP_MOUNT_DRIVE"
    echo "$SETUP_MOUNT_OUTPUT"
    read noop

    #qemu-system-arm -kernel ~/qemu_vms/<your-kernel-qemu> \
    #    -cpu arm1176 \
    #    -m 256 \
    #    -M versatilepb \
    #    -serial stdio \
    #    -append "root=/dev/sda2 rootfstype=ext4 rw" \
    #    -hda ~/qemu_vms/<your-jessie-image.img> \
    #    -redir tcp:2022::22 \
    #    -no-reboot
}

mount-image() {
    local image=${1:-$SETUP_IMAGE_FILE}

    # Mount the image as a volume mount, to expose the boot dir for updates
    # See also: https://www.janosgyerik.com/mounting-a-raspberry-pi-image-on-osx/
    SETUP_MOUNT_OUTPUT="$(hdiutil mount "$image")"
    SETUP_MOUNT_DRIVE="$(echo "$SETUP_MOUNT_OUTPUT" | grep FDisk_partition_scheme | xargs | cut -d ' ' -f1)"
    SETUP_MOUNT_BOOT="$(echo "$SETUP_MOUNT_OUTPUT" | grep Windows_FAT_32 | xargs | cut -d ' ' -f3)"

    # Unmount drive and volume(s) once we are done with this function
    trap "[ ! -d "$SETUP_MOUNT_DRIVE" ] || hdiutil eject $SETUP_MOUNT_DRIVE" EXIT
}

# ----------------------------

setup-boot-config() {
    local file="$1"
    local json="$2"
    local type="$(echo "$json" | yq '. | tag')"
    case ${type:-""} in
        !!map) 
            # File is expressed as a key vaulue map
            echo " + $file < [$type]"
            while read json; do
                local key="$(echo "$json" | yq -r '.key')"
                local val="$(echo "$json" | yq -r '.value')"
                case ${key:-""} in
                    *) 
                        # Change config value
                        echo "    + $key: $val"
                        boot-append "$boot/$file" "$key=$val"
                    ;;
                esac
            done < <(echo $json | yq -oj -I0 '. | to_entries[]' )
        ;;
        *) throw "[$type] Unknown input: $json";;
    esac
}

setup-cmdline-apply() {
    local term="$1"
    local after="${2:-}"
    local file="$SETUP_MOUNT_BOOT/cmdline.txt"

    echo " + cmdline.txt    < $term"
    
    if grep -q "$term" "$file"; then
        return 0 # Already found
    fi

    if [ -z "${after:-}" ]; then
        sed -i '' "s|\$| $term|" "$file"
    else 
        sed -i '' "s|$after|$after $term|" "$file"
    fi
}

setup-boot-overlay() {
    local file="$1"
    local value="${2:-"$(cat /dev/stdin)"}"
    
    echo " + $file"
    echo "${value:-}" > "$SETUP_MOUNT_BOOT/$file"
}

download-image() {
    local url="$1"
    local out="$2"

    mkdir -p "$out.tmp"
    curl -s -Lo "$out.zip" "$url"

    tar -xvzf "$out.zip" -C "$out.tmp"
    cp -f "$(find "$out.tmp" -name '*.img' | head -n 1)" "$out"
    rm -rf "$out.tmp"
    rm -f "$out.zip"
}

copy-image() {
    local file="$1"
    local path="$2"

    echo "Writing image '$file' to '$path'...(requires sudo)"

    # diskutil list | grep "(external, physical)" | awk '{print $1}'    
    diskutil unmountDisk "$path"
    sudo dd bs=1m if="$file" of="$path"
    sleep 1
}

boot-append() {
    local file="$1"
    local feat="$2"
    if ! grep -q "$feat" "$file"; then
        echo "$feat" >> "$file"
    fi
}

list-drives() {
    diskutil list | grep "(external, physical)" | awk '{print $1}'
}


prompt-image-file() {
    # Select the disk image file to use when buring the image or ddownload    
    : "${SETUP_IMAGE_FILE:="$(gum file --header="Select disk image you want to set up" ./images)"}"
    : "${SETUP_IMAGE_URL:="$(cat ./images/_new.img)"}"

    # Check if the user specified downloading from a URL
    if echo "$SETUP_IMAGE_FILE" | grep -E "_new.img$" > /dev/null; then
        SETUP_IMAGE_URL="$(gum input --header="Select image download URL" --value="$SETUP_IMAGE_URL")"
        SETUP_IMAGE_NAME="$(gum input --header="Select image name" --value="$(basename $SETUP_IMAGE_URL).img")"
        SETUP_IMAGE_FILE="./images/$SETUP_IMAGE_NAME"
        
        #echo "Download image: $SETUP_IMAGE_FILE < $SETUP_IMAGE_URL" 1>&2
        #download-image "$SETUP_IMAGE_URL" "$SETUP_IMAGE_FILE" 1>&2
        gum spin --spinner dot --title "Download image: $SETUP_IMAGE_URL" -- "$0" download "$SETUP_IMAGE_URL" "$SETUP_IMAGE_FILE" > /dev/null
    fi

    echo "$SETUP_IMAGE_FILE"
}

prompt-volume-mount() {
    : "${SETUP_VOLUME_MOUNT:="(refresh list)"}"

    while [ "${SETUP_VOLUME_MOUNT:-}" == "(refresh list)" ]; do
        SETUP_VOLUME_MOUNT="$(cat <<- EOF | gum choose --header="Select volume mount to burn image to" --limit 1
$(list-drives)
(refresh list)
(custom path)
EOF
)"
    done
    
    if [ "${SETUP_VOLUME_MOUNT:-}" == "(custom path)" ]; then
        SETUP_VOLUME_MOUNT="$(gum input --header="Select volume mount path" --value="")"
    fi

    echo "${SETUP_VOLUME_MOUNT:-}"
}


throw() {
    red=$([ -z $TERM ] || printf "\033[0;31m")
    reset=$([ -z $TERM ] || printf "\e[0m")
    printf "${red:-}$1${reset:-}\n" >&2
    exit 1
}

# Bootstrap the script
main $@