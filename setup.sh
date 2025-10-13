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
        image) setup-image $@;; # Download and generate a bootable image
        disk) setup-disk $@;; # Burn an image to the SD card mounted as a volume
        boot) setup-boot $@;; # Set the boot modifications for SD card on first use
        *) # Command not found, show help
            help && exit 1
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
        printf "Hint: Install 'gum' for better interactive command line experience.\n"
    fi    
}

config-interactive() {
    # Set basic formatting
    C_PRIMARY=12
    F_PRIMARY="gum style --foreground $C_PRIMARY"

    # Display the headers for this script
    gum style \
        --border normal \
        --margin "1" \
        --padding "1 2" \
        --border-foreground $C_PRIMARY \
        "`$F_PRIMARY '📦 Raspberry Pi Zero'` - Setup a SD Card image"

    # Select the action (if not already selected)
    : "${ACTION:="$(prompt-action)"}"
}

setup-init() {
    SETUP_IMAGE_URL="$(gum input --header="SETUP_IMAGE_URL" --value="${SETUP_IMAGE_URL:-'https://downloads.raspberrypi.org/raspbian_lite_latest'}")"
    SETUP_ADMIN_USER="$(gum input --header="SETUP_ADMIN_USER" --value="${SETUP_ADMIN_USER:-}")"
    SETUP_ADMIN_PASS="$(gum input --header="SETUP_ADMIN_PASS" --value="${SETUP_ADMIN_PASS:-}" --password)"

    SETUP_NETWORK_HOSTNAME="$(gum input --header="SETUP_NETWORK_HOSTNAME" --value="${SETUP_NETWORK_HOSTNAME:-}")"
    SETUP_NETWORK_SSH_ENABLED="$(gum input --header="SETUP_NETWORK_SSH_ENABLED" --value="${SETUP_NETWORK_SSH_ENABLED:-true}")"

    env | grep SETUP_
}

setup-image() {
    # Select the disk image file to use when buring the image
    : "${SETUP_IMAGE_FILE:=${1:-"$(prompt-image-file)"}}"

    # Mount the image as a volume mount, to expose the boot dir for updates
    # See also: https://www.janosgyerik.com/mounting-a-raspberry-pi-image-on-osx/
    SETUP_MOUNT_OUTPUT="$(hdiutil mount "$SETUP_IMAGE_FILE")"
    SETUP_MOUNT_DRIVE="$(echo "$SETUP_MOUNT_OUTPUT" | grep FDisk_partition_scheme | xargs | cut -d ' ' -f1)"
    SETUP_MOUNT_BOOT="$(echo "$SETUP_MOUNT_OUTPUT" | grep Windows_FAT_32 | xargs | cut -d ' ' -f3)"

    # Unmount drive and volume(s) once we are done with this function
    trap "[ ! -d "$SETUP_MOUNT_DRIVE" ] || hdiutil eject $SETUP_MOUNT_DRIVE" EXIT

    # Update the image boot partition with our selected features
    [ -z "${SETUP_MOUNT_BOOT:-}" ] || setup-boot "$SETUP_MOUNT_BOOT"

    # Check if we should burn the resulting image
    if gum confirm "Burn to SD Card?"; then
        # Burn image to SD card
        setup-disk
    else
        # Unmount disk and release sources, as we no longer need it
        hdiutil eject $SETUP_MOUNT_DRIVE
    fi
}

setup-disk() {
    : "${SETUP_IMAGE_FILE:=${1:-"$(prompt-image-file)"}}"
    : "${SETUP_VOLUME_MOUNT:=${2:-"$(prompt-volume-mount)"}}"

    [ -d "${SETUP_VOLUME_MOUNT:-}" ] || throw "Unknown volume mount: ${SETUP_VOLUME_MOUNT:-}"
    
    # Burn the base image to the SD Card image
    echo "Copying image: $SETUP_IMAGE_FILE > $SETUP_VOLUME_MOUNT"
    copy-image "$SETUP_IMAGE_FILE" "$SETUP_VOLUME_MOUNT"
}

setup-boot() {
    local path=${1:-""}

    # Stop the script here if no boot volume was specified
    [ -d "${path:-}" ] || throw "The boot path '${path:-}' does not exists."
    
    setup-boot-image "$path"
    
    # Generate setup configurations
    setup-boot-settings "$path"
}

# ----------------------------

setup-get() {
    local value=$(yq -r $@ setup.yaml)
    [ "${value:-"null"}" != "null" ] && echo "$value" && return 0 || return 1
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
    diskutil list | grep "(external, physical)" | awk '{print $1}'
}

prompt-action() {
    cat <<- EOF | gum choose --header="Setup action to perform?" --limit 1
init
image
disk
EOF
}

prompt-image-file() {
    # Select the disk image file to use when buring the image or ddownload    
    : "${SETUP_IMAGE_FILE:="$(cat <<- EOF | gum choose --header="Select disk image to use with your Raspberry pi" --limit 1
$(find ./images -type f 2> /dev/null || true)
(download from URL)
EOF
)"}"

    # Check if the user specified downloading from a URL
    if [ "$SETUP_IMAGE_FILE" == "(download from URL)" ]; then
        SETUP_IMAGE_URL="$(gum input --header="Select image download URL" --value="https://downloads.raspberrypi.org/raspbian_lite_latest")"
        SETUP_IMAGE_NAME="$(gum input --header="Select image name" --value="$(basename $SETUP_IMAGE_URL).img")"
        SETUP_IMAGE_FILE="./images/$SETUP_IMAGE_NAME"
        echo "Download image: $SETUP_IMAGE_FILE < $SETUP_IMAGE_URL" 1>&2
        download-image "$SETUP_IMAGE_URL" "$SETUP_IMAGE_FILE" 1>&2
    fi

    echo "$SETUP_IMAGE_FILE"
}

prompt-volume-mount() {
    : "${SETUP_VOLUME_MOUNT:="$(cat <<- EOF | gum choose --header="Select volume mount to burn image to" --limit 1
$(list-drives)
(custom path)
EOF
)"}"
    
    if [ "${SETUP_VOLUME_MOUNT:-}" == "(custom path)" ]; then
        SETUP_VOLUME_MOUNT="$(gum input --header="Select volume mount path" --value="")"
    fi

    echo "${SETUP_VOLUME_MOUNT:-}"
}

throw() {
    red=$([ -z $TERM ] || printf "\033[0;31m")
    reset=$([ -z $TERM ] || printf "\e[0m")
    printf "${red:-}$1${reset:-}\n"
    exit 1
}

# Bootstrap the script
main $@