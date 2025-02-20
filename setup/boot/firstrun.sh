#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
set +e
# --------------------------------------------------------------
: "${BOOT_PATH:="/boot"}"
: "${BOOT_INIT:="$BOOT_PATH/init.d"}"

main() {
   # Run all boot init scripts
   if [ -d "$BOOT_INIT" ]; then
      find "$BOOT_INIT" -type f -exec echo {} \; 
   fi

   # Remove init scripts after first successful run
   cleanup
}

init() {
   local script=$1
   [ -f $script ] || return 0
   "$script" $@
}

cleanup() {
   # Remove init scripts after first successful run
   rm -f "$BOOT_PATH/firstrun.sh"
   if [ -f "$BOOT_PATH/cmdline.txt" ]; then
      sed -i 's| systemd.run.*||g' "$BOOT_PATH/cmdline.txt"
   fi
}

main $@ # <-- Bootstrap script