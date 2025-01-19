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
    echo "Setup a SD Card image for a Raspberry Pi"
    echo ""
    echo "Basic Usage:"
    echo "  $0 ${RPI_IMAGE_DISK:-"<disk-mount>"} <volume-boot-path>"
    echo ""
}

config() {
    # Set the core installation config settings
    RPI_IMAGE_DISK=${1:-"$(diskutil list | grep "(external, physical)" | awk '{print $1}')"}
    RPI_BOOT_PATH=${2:-""}
    
    RPI_IMAGE_FILE=${RPI_IMAGE_FILE:-"./images/current.img"}
    RPI_IMAGE_URL=${RPI_IMAGE_URL:-"https://downloads.raspberrypi.org/raspbian_lite_latest"}

    RPI_WIFI_TYPE=${RPI_WIFI_TYPE:-"WPA-PSK"}
    RPI_WIFI_SSID=${RPI_WIFI_SSID:-""}
    RPI_WIFI_PSK=${RPI_WIFI_PSK:-""}
    RPI_WIFI_COUNTRY=${RPI_WIFI_COUNTRY:-}

    # Action is required
    [ ! -z "${RPI_IMAGE_DISK:-}" ] || (help && exit 1)
    [ ! -z "${RPI_BOOT_PATH:-}" ] || (help && exit 1)
}

main() {
    # Setup basic config and check for an active internet connection
    config $@

    # Download the base image (if not available)    
    [ -f "$RPI_IMAGE_FILE" ] || download-image "$RPI_IMAGE_URL" "$RPI_IMAGE_FILE"

    # Burn the base image and add additional config
    copy-image "$RPI_IMAGE_FILE" "$RPI_IMAGE_DISK"
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

fatal() {
    red=$([ -z $TERM ] || printf "\033[0;31m")
    reset=$([ -z $TERM ] || printf "\e[0m")
    printf "${red:-}$1${reset:-}\n"
    exit 1
}

# Bootstrap the script
main $@