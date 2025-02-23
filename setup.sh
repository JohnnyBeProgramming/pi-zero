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
    
    # Generate setup configurations
    setup-boot-settings "$path"
    
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

    # Apply boot file modifications
    while read ident; do
        local json="$(yq -o=json -I0 ".boot[\"$ident\"]" setup.yaml)"
        case ${ident:-""} in
            overlays) true;;
            config.txt) setup-boot-config "$ident" "$json";;
            cmdline.txt) setup-boot-cmdline "$ident" "$json";;
            *) setup-boot-file-overlay "$ident" "$json";;
        esac
    done < <(yq '.boot | keys[]' setup.yaml)    

    # Apply overlays from the setup.yaml file(s)
    while read json; do         
        setup-boot-overlay "$boot" "$json";
    done < <(setup-get -o=json -I0 '.boot.overlays[]')
     
}

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

setup-boot-cmdline() {
    local file="$1"
    local json="$2"
    local type="$(echo "$json" | yq '. | tag')"
    case ${type:-""} in
        !!map) 
            # Write string output to file
            echo " + $file < [$type]"
            while read json; do
                setup-boot-cmdline-item "$json" 
            done < <(echo $json | yq -oj -I0 '. | to_entries[]' )
        ;;
        *) throw "[$type] Unknown input: $json";;
    esac
}

setup-boot-cmdline-item() {
    local json="$1"
    local key="$(echo "$json" | yq -r '.key')"
    local val="$(echo "$json" | yq -oj -I0 '.value')"
    local type="$(echo "$val" | yq '. | tag')"
    local data=""
    case ${type:-""} in
        !!str) 
            # Use string value as is
            data="$(echo "$val" | yq -r '.')"
            setup-boot-cmdline-item-apply "$key" "$data"
        ;;
        !!seq) 
            # Merge list as comma separated
            data="$(echo "$val" | yq -P '. | join(",")')"
            setup-boot-cmdline-item-apply "$key" "$data"
        ;;
        !!map) 
            # Merge map into key value pairs
            while read json; do
                local prop="$(echo $json | yq '.key')"
                local val="$(echo $json | yq '.value')"
                setup-boot-cmdline-item-apply "$prop" "$val"
            done < <(echo "{ "$key": $val }" | yq -oj -I0 '
                .. 
                | select(. == "*") 
                | {
                    (path | . as $x | (.[] | select((. | tag) == "!!int") |= (["[", ., "]"] | join(""))) | $x | join(".") | sub(".\[", "[")): .
                  } 
                | to_entries[]
            ')
        ;;
        *) throw "[$type] Unknown input: $json";;
    esac
}

setup-boot-cmdline-item-apply() {
    local key="$1"
    local data="$2"

    echo "    + $key=$data"

    # Handle edhe cases
    case ${key:-""} in
        modules-load) 
            boot-replace "$boot/$file" "rootwait" "rootwait $key=$data";; 
        *)  boot-replace "$boot/$file" "\$" " $key=$data";;
    esac
}

setup-boot-file-overlay() {
    local file="$1"
    local json="$2"
    local type="$(echo "$json" | yq '. | tag')"
    case ${type:-""} in
        !!str) 
            # Write string output to file
            echo " + $file < [$type]"
            echo "$(echo "$json" | yq -r)" > "$boot/$file"
        ;;
        *) throw "[$type] Unknown input: $json";;
    esac
}

setup-boot-settings() {
    local boot="$1"
    local config="$boot/setup.env"

    echo "Creating boot config: $config"
    echo "" > "$config"

    # Root user name and password
    cat << EOF >> "$config"
export USER_NAME=${USER_NAME:-"$(setup-get '.admin.user')"}
export USER_PASS=${USER_PASS:-"$(setup-get '.admin.pass')"}
EOF

    # Locale and keyboard layout
    cat << EOF >> "$config"
export LOCALE_TZ="${LOCALE_TZ:-}"
export KEYBOARD_LAYOUT="${KEYBOARD_LAYOUT:-}"
export KEYBOARD_MODEL="${KEYBOARD_MODEL:-}"
EOF

    # Network settings
    cat << EOF >> "$config"
export DESIRED_HOSTNAME="$(setup-get '.network.hostname')"
export SSH_ENABLE="$(setup-get '.network.ssh.enabled')"
export WIFI_COUNTRY="${WIFI_COUNTRY:-"$(setup-get '.network.wifi.country')"}"
export WIFI_SSID="${WIFI_SSID:-"$(setup-get '.network.wifi.ssid')"}"
export WIFI_PSK="${WIFI_PSK:-"$(setup-get '.network.wifi.psk')"}"
EOF

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