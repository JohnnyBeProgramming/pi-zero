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
Setup a SD Card image for a Raspberry Pi

Basic Usage:
  $0 ACTION [ args ]

Actions:
  image <disk-mount> [ <volume-boot-path> ]
  boot <volume-boot-path>

Disk Mounts:
$(diskutil list | grep "(external, physical)" | awk '{print $1}' | sed 's|^| - |')

Volume Boot Path:
 - This is the mounted path to the boot drive
 - Copies and modified the base image with the current setup
 - eg: /Volumes/boot/
EOF
}

main() {
    ACTION=${1:-}; [ -z "${1:-}" ] || shift;

    case ${ACTION:-"default"} in
        default) help;;
        image) setup-image $@;;
        boot) setup-boot $@;;
        wifi) setup-wifi;;
        *) help && exit 1
    esac    
}

setup-image() {
    # Check for required args
    RPI_IMAGE_DISK=${1:-""}
    RPI_BOOT_PATH=${2:-""}

    [ ! -z "${RPI_IMAGE_DISK:-}" ] || (help && exit 1)

    : "${RPI_IMAGE_FILE:="$(yq -r '.image.file' setup.yaml)"}"
    : "${RPI_IMAGE_FILE:="./images/current.img"}"
    : "${RPI_IMAGE_URL:="$(yq -r '.image.url' setup.yaml)"}"
    : "${RPI_IMAGE_URL:="https://downloads.raspberrypi.org/raspbian_lite_latest"}"

    # Download the base image (if not available)    
    if [ ! -f "$RPI_IMAGE_FILE" ]; then
        download-image "$RPI_IMAGE_URL" "$RPI_IMAGE_FILE"
    fi

    # Burn the base image and add additional config
    copy-image "$RPI_IMAGE_FILE" "$RPI_IMAGE_DISK"

    if [ ! -z "${RPI_BOOT_PATH:-}" ]; then
        setup-boot "$RPI_BOOT_PATH"
    fi
}

setup-boot() {
    RPI_BOOT_PATH=${1:-""}

    # Stop the script here if no boot volume was specified
    [ ! -z "${RPI_BOOT_PATH:-}" ] || (help && exit 1)
    [ -d "${RPI_BOOT_PATH:-}" ] || throw "The boot path '${RPI_BOOT_PATH:-}' does not exists."

    echo "Updating SD Card boot config: $RPI_BOOT_PATH"
    setup-boot-image "$RPI_BOOT_PATH"
}

setup-wifi() {
    RPI_WIFI_TYPE=${RPI_WIFI_TYPE:-"$(yq -r '.network.wifi.type' setup.yaml)"}
    RPI_WIFI_SSID=${RPI_WIFI_SSID:-"$(yq -r '.network.wifi.ssid' setup.yaml)"}
    RPI_WIFI_PSK=${RPI_WIFI_PSK:-"$(yq -r '.network.wifi.psk' setup.yaml)"}
    RPI_WIFI_COUNTRY=${RPI_WIFI_COUNTRY:-"$(yq -r '.network.wifi.country' setup.yaml)"}

    # Set additional defaults
    : "${RPI_WIFI_TYPE:="WPA-PSK"}"
    : "${RPI_WIFI_SSID:=""}"
    : "${RPI_WIFI_PSK:=""}"
    : "${RPI_WIFI_COUNTRY:=""}"

}

setup-boot-image() {
    local boot="$1"

    # Apply overlays from the setup.yaml file
    #while read json; do 
    #    setup-boot-overlay "$json"; 
    #done < <(yq -r -o=json -I0 '.overlays[]' $THIS_DIR/setup.yaml)
    #
    #while read file; do
    #    local out="$boot/$file"
    #    while read json; do
    #        echo " + $out < $json"
    #    done < <(yq -r -o=json -I0 ".boot[\"${file}\"][]" setup.yaml)
    #done < <(yq -r '.boot | keys[]' $THIS_DIR/setup.yaml)
    #exit 0

    boot-append "$boot/config.txt" "dtoverlay=dwc2"
    boot-replace "$boot/cmdline.txt" "rootwait" "rootwait modules-load=dwc2,g_ether"
    boot-write "$boot/ssh.txt" ""

    # Setup wifi if settings were included
    boot-setup-wifi
    
    # Notify user to unmount and add SD card
    echo "You can now unmount the SD card and add to the pi device"
}

setup-boot-file() {
    local path="$1"
    local out="${2:-"$RPI_BOOT_PATH/$(basename $path)"}"
    echo " + $out"
    cat "$path" | envsubst > "$out"
}

setup-boot-overlay() {
    local json="$1"

    # yq -r -o=json -I0 '.overlays[]' setup.yaml
    echo " ± $json"
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