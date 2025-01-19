#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
# This script is used to add additional setup scripts to an image
# boot drive for raspberry pi's
# --------------------------------------------------------------
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

help() {
    echo "Setup a SD Card image for a Raspberry Pi"
    echo ""
    echo "Basic Usage:"
    echo "  $0 <disk-mount> [ <volume-boot-path> ]"
    echo ""
    echo "Disk Mounts:"
    diskutil list | grep "(external, physical)" | awk '{print $1}' | sed 's|^| - |'
    echo ""
    echo "(optional) Volume Boot Path:"
    echo " - This is the mounted path to the boot drive"
    echo " - Copies and modified the base image with the current setup"
    echo " - eg: /Volumes/boot/"
    echo ""
}

config() {
    # Set the core installation config settings
    RPI_IMAGE_DISK=${1:-"$(diskutil list | grep "(external, physical)" | awk '{print $1}')"}
    RPI_BOOT_PATH=${2:-""}

    # Check for required args
    [ ! -z "${RPI_IMAGE_DISK:-}" ] || (help && exit 1)

    # Load ENV from file (if exists)
    [ ! -f "$THIS_DIR/setup.env" ] || source "$THIS_DIR/setup.env" # Persisted env
    [ ! -f "$THIS_DIR/.env" ] || source "$THIS_DIR/.env" # Secrets (wifi, password, ect)
    
    # Set additional defaults
    : "${RPI_IMAGE_FILE:="./images/current.img"}"
    : "${RPI_IMAGE_URL:="https://downloads.raspberrypi.org/raspbian_lite_latest"}"
    : "${RPI_WIFI_TYPE:="WPA-PSK"}"
    : "${RPI_WIFI_SSID:=""}"
    : "${RPI_WIFI_PSK:=""}"
    : "${RPI_WIFI_COUNTRY:=""}"
}

main() {
    # Setup basic config and check for an active internet connection
    config $@

    # Download the base image (if not available)    
    if [ ! -f "$RPI_IMAGE_FILE" ]; then
        download-image "$RPI_IMAGE_URL" "$RPI_IMAGE_FILE"
    fi

    # Burn the base image and add additional config
    #copy-image "$RPI_IMAGE_FILE" "$RPI_IMAGE_DISK"

    # Stop the script here if no boot volume was specified
    [ ! -z "${RPI_BOOT_PATH:-}" ] || return
    [ -d "${RPI_BOOT_PATH:-}" ] || throw "The boot path '${RPI_BOOT_PATH:-}' does not exists."

    echo "Updating boot config settings in '$RPI_BOOT_PATH'..."
    
    # Copy file that was staged from the setup/boot folder
    while read path; do
        local file="$(basename $path)"
        local out="$RPI_BOOT_PATH/$file"
        echo " + $out"
        cat "$path" | envsubst > "$out"
    done < <(find "$THIS_DIR/setup/boot" -type f)

    # Apply overlays from the setup.yaml file
    while read file; do
        local out="$RPI_BOOT_PATH/$file"
        while read json; do
            echo " + $out < $json"
        done < <(yq -r -o=json -I0 ".boot[\"${file}\"][]" setup.yaml)
    done < <(yq -r '.boot | keys[]' $THIS_DIR/setup.yaml)
    exit 0

    boot-append "$RPI_BOOT_PATH/config.txt" "dtoverlay=dwc2"
    boot-replace "$RPI_BOOT_PATH/cmdline.txt" "rootwait" "rootwait modules-load=dwc2,g_ether"
    boot-write "$RPI_BOOT_PATH/ssh.txt" ""

    # Setup wifi if settings were included
    boot-setup-wifi
    
    # Notify user to unmount and add SD card
    echo "You can now unmount the SD card and add to the pi device"
}

download-image() {
    local url="$1"
    local out="$2"

    mkdir -p "$out.tmp"
    curl -Lo "$out.zip" "$url"

    tar -xvzf "$out.zip" -C "$out.tmp"
    cp -f "$(find "$out.tmp" -name '*.img' | head -n 1)" "$out"
    rm -rf "$out.tmp"
    rm -f "$out.zip"
}

copy-image() {
    local file="$1"
    local path="$2"

    echo "Writing image '$file' to '$path'..."

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

boot-replace() {
    local file="$1"
    local term="$2"
    local feat="$3"

    if ! grep -q "$feat" "$file"; then  
        sed -i '' "s|$term|$feat|" "$file"
    fi
}

boot-write() {
    local file=$1
    local data=$2
    mkdir -p "$(dirname "$file")"
    echo "$data" > "$file"
}

boot-setup-wifi() {
    [ ! -z "${RPI_WIFI_TYPE:-}" ] || return
    [ ! -z "${RPI_WIFI_SSID:-}" ] || return
    [ ! -z "${RPI_WIFI_PSK:-}" ] || return
    [ ! -z "${RPI_WIFI_COUNTRY:-}" ] || return

    echo "Setting up WIFI: $RPI_BOOT_PATH/wpa_supplicant.conf"
    boot-write "$RPI_BOOT_PATH/wpa_supplicant.conf" "$(cat << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=$RPI_WIFI_COUNTRY

network={
	ssid="$RPI_WIFI_SSID"
	psk="$RPI_WIFI_PSK"
	key_mgmt=$RPI_WIFI_TYPE
}
EOF
)"
}

throw() {
    red=$([ -z $TERM ] || printf "\033[0;31m")
    reset=$([ -z $TERM ] || printf "\e[0m")
    printf "${red:-}$1${reset:-}\n"
    exit 1
}

# Bootstrap the script
main $@