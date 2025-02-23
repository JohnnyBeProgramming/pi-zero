#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
set +e
# --------------------------------------------------------------
: "${BOOT_PATH:=${1:-"/boot"}}"
: "${BOOT_INIT:="$BOOT_PATH/init.d"}"
: "${BOOT_CONF:="$BOOT_PATH/setup.env"}"

main() {
   # Load settings (if defined)
   echo "Loading settings: $BOOT_CONF"
   [ ! -f "$BOOT_CONF" ] || source "$BOOT_CONF"

   # Run all boot init scripts
   echo "Boot init: $BOOT_INIT"
   if [ -d "$BOOT_INIT" ]; then      
      while read script; do         
        echo " + $script"
        #"$script"
      done < <(find "$BOOT_INIT" -type f -exec echo {} \;) 
   fi

   # Remove init scripts after first successful run
   echo TODO cleanup
}

cleanup() {
   # Remove init scripts after first successful run
   rm -f "$BOOT_PATH/setup.env"
   rm -f "$BOOT_PATH/init.d/"
   rm -f "$BOOT_PATH/firstrun.sh"
   if [ -f "$BOOT_PATH/cmdline.txt" ]; then
      sed -i 's| systemd.run.*||g' "$BOOT_PATH/cmdline.txt"
   fi
}

main $@ > $BOOT_PATH/boot.log 2> $BOOT_PATH/boot.errors # <-- Bootstrap script