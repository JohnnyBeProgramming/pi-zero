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
$(list-drives)

Volume Boot Path:
 - This is the mounted path to the boot drive
 - Copies a modified base image with the selected setup
 - eg: /Volumes/boot/
EOF
}

config() {
    [ ! -f .env ] || export $(xargs < .env) # Load untracked secrets

    # Read the global command line args
    ACTION=${1:-}; [ -z "${1:-}" ] || shift;

    # Prompt the user for inputs (if not already specified)
    config-interactive
}

config-interactive() {
    : "${ACTION:="$(ask choose --header "Action?" "init" "image" "boot")"}"
}

ask() {
    if which gum > /dev/null; then
        gum $@
    fi
}

main() {
    config $@
    
    case ${ACTION:-""} in
        init) 
            setup-init
            ;;
        image) 
            # Generate the bootable image
            setup-image $@

            # Apply the boot settings (if specified)
            [ -z "${2:-}" ] || setup-boot "${2:-}"
            ;;
        boot) 
            # Set the boot modifications for SD card on first use
            setup-boot $@;;
        *) 
            # Command not found, show help
            help && exit 1
    esac    
}

setup-init() {
    SETUP_IMAGE_URL="$(ask input --header="SETUP_IMAGE_URL" --value="${SETUP_IMAGE_URL:-'https://downloads.raspberrypi.org/raspbian_lite_latest'}")"
    SETUP_ADMIN_USER="$(ask input --header="SETUP_ADMIN_USER" --value="${SETUP_ADMIN_USER:-}")"
    SETUP_ADMIN_PASS="$(ask input --header="SETUP_ADMIN_PASS" --value="${SETUP_ADMIN_PASS:-}" --password)"

    SETUP_NETWORK_HOSTNAME="$(ask input --header="SETUP_NETWORK_HOSTNAME" --value="${SETUP_NETWORK_HOSTNAME:-}")"
    SETUP_NETWORK_SSH_ENABLED="$(ask input --header="SETUP_NETWORK_SSH_ENABLED" --value="${SETUP_NETWORK_SSH_ENABLED:-true}")"

    env | grep SETUP_
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

    # Add the local volumes to includes 
    setup-volumes "$boot"
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
    local config="$boot/volumes/setup.env"

    echo "Creating setup config: $config"
    mkdir -p "$(dirname $config)"
    echo "# Auto generated settings" > "$config"

    # Convert the setup YAML to to ENV compatable vars 
    yq -P '
        . | del(.includes,.boot) | 
        .. | select(. == "*") | [
            "SETUP_" + (path | join("_") | upcase) + "=" + (. | to_json)
        ] | join("")' setup.yaml \
    | envsubst \
    | grep -v -e '^$' \
    >> "$config"

    # Track the tools and services that we want to install on first boot
    SETUP_TOOLS=()    
    while read tool; do         
        SETUP_TOOLS+=("$tool")
    done < <(yq -P '.tools | to_entries[] | select(.value != false) | (
        .key + "=" + .value | sub("=true"; "")
    )' setup.yaml)

    SETUP_SERVICES=()
    while read service; do 
        SETUP_SERVICES+=("$service")
    done < <(yq -oj -I0 '.services | to_entries[] | select(.value != false) | (
        .key
    )' setup.yaml)

    cat << EOF >> "$config"

# Setup additional tools
SETUP_TOOLS=(${SETUP_TOOLS[@]:-})

# Install system services
SETUP_SERVICES=(${SETUP_SERVICES[@]:-})
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

setup-volumes() {
    local base=$1

    echo "Setting up volumes..."
    mkdir -p "$base/volumes/"
    while read json; do
        local key="$(echo "$json" | yq '.key')"
        local val="$(echo "$json" | yq '.value')"
        local path="$THIS_DIR/$(basename $key)"
        if [ -d "${path}" ]; then
            setup-volume-archive "$key" "$path" "$base"
        else
            echo "Warning: Path '$path' not found"
        fi
    done < <(setup-get -o=json -I0 '.volumes' | yq -oj -I0 '. | to_entries[]')
}

setup-volume-archive() {
    local target=$1
    local path=$2
    local base=$3

    echo " + $target: $path";
    tar zcf - "$path" > "$base/volumes/$(basename $target).tar.gz"
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

list-drives() {
    diskutil list | grep "(external, physical)" | awk '{print $1}' | sed 's|^| - |' || echo " - No disks available"
}

throw() {
    red=$([ -z $TERM ] || printf "\033[0;31m")
    reset=$([ -z $TERM ] || printf "\e[0m")
    printf "${red:-}$1${reset:-}\n"
    exit 1
}

# Bootstrap the script
main $@