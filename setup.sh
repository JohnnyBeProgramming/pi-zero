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

    [ ! -f .env ] || source .env # Load untracked secrets

    case ${ACTION:-""} in
        image) 
            setup-image $@
            [ -z "${2:-}" ] || setup-boot "${2:-}"
            ;;
        boot) setup-boot $@;;
        *) help && exit 1
    esac    
}

setup-get() {
    local value=$(yq -r $@ setup.yaml)
    [ "${value:-"null"}" != "null" ] && echo "$value" && return 0 || return 1
}

setup-image() {
    # Check for required args
    local disk=${1:-"$(help && exit 1)"}
    local url=$(setup-get ".image.url" || echo "https://downloads.raspberrypi.org/raspbian_lite_latest")
    local file=$(setup-get ".image.file" || echo "./images/$(basename $url).img")

    echo "Copying image: $disk < $file = $url"

    # Download the base image (if not available)
    [ -f "$file" ] || download-image "$url" "$file"

    # Burn the base image and add additional config
    copy-image "$file" "$disk"    
}

setup-boot() {
    local path=${1:-""}

    # Stop the script here if no boot volume was specified
    [ -d "${path:-}" ] || throw "The boot path '${path:-}' does not exists."
    
    setup-boot-image "$path"
    
    # Notify user to unmount and add SD card
    echo "You can now unmount the SD card and add to the pi device"
}

setup-boot-image() {
    local boot="$1"
    local boot_files="./setup/boot"

    echo "Updating SD Card boot config: $path"

    # Copy pre-defined boot files
    if [ -d "$boot_files" ]; then 
        echo "Copying boot files from: $boot_files"
        cp -rf "$boot_files/" "$path"
    fi

    # Apply overlays from the setup.yaml file(s)
    while read json; do         
        setup-boot-overlay "$boot" "$json";
    done < <(setup-get -o=json -I0 '.boot.overlays[]')
    
    #while read file; do
    #    local out="$boot/$file"
    #    while read json; do
    #        echo " + $out < $json"
    #    done < <(yq -r -o=json -I0 ".boot[\"${file}\"][]" setup.yaml)
    #done < <(yq -r '.boot | keys[]' $THIS_DIR/setup.yaml)
    #exit 0

    #boot-append "$boot/config.txt" "dtoverlay=dwc2"
    #boot-replace "$boot/cmdline.txt" "rootwait" "rootwait modules-load=dwc2,g_ether"
    #boot-write "$boot/ssh.txt" ""    
}

setup-boot-overlay() {
    local boot="${1:-"$(help && exit 1)"}"
    local json="${2:-"{}"}"
    local file="$(echo "$json" | yq -r '.file')"
    local test="$(echo "$json" | yq -r '.test')"
    local data="$(echo "$json" | yq -r '.data')"
    local config="$(echo "$json" | yq -r '. | del(.file, .test)')"
    local append="$(echo "$json" | yq -r '.append')"
    local replace="$(echo "$json" | yq -r '.replace')"
    local exists="$(echo "$json" | yq -r '.exists')"
    
    # Check if there is a test for this overlay
    if [ -f "$boot/$file" ] && [ ! -z "${test:-}" ] && grep -E "$test" "$boot/$file" > /dev/null; then
        printf " ✓ %s ~ %s \n" "$boot/$file" "$test"
        return # Test passed, up to date
    fi

    if [ "${append:-"null"}" != "null" ]; then
        grep "$append" "$boot/$file" > /dev/null 2>&1 && return || true
        printf " + %s << %s \n" "$boot/$file" "$append"
        boot-append "$boot/$file" "$append"
        return
    fi

    if [ "${replace:-"null"}" != "null" ]; then
        grep "${data:-}" "$boot/$file" > /dev/null 2>&1 && return || true
        printf " + %s < ['%s'='%s']\n" "$boot/$file" "$replace" "$data"
        boot-replace "$boot/$file" "$replace" "$data"
        return
    fi

    # Write raw data if no other actions applied
    if [ ! -z "$(echo "$json" | yq -r '. | keys' | grep "data")" ]; then
        printf " ± %s < %s\n" "$boot/$file" "data..."
        echo "${data:-}" > "$boot/$file"
        return
    fi

    throw " ? $file < $config\n"
}

setup-boot-file() {
    local path="$1"
    local out="${2:-"$RPI_BOOT_PATH/$(basename $path)"}"
    echo " + $out"
    cat "$path" | envsubst > "$out"
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

throw() {
    red=$([ -z $TERM ] || printf "\033[0;31m")
    reset=$([ -z $TERM ] || printf "\e[0m")
    printf "${red:-}$1${reset:-}\n"
    exit 1
}

# Bootstrap the script
main $@