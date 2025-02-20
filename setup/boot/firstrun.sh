#!/bin/bash

set +e

main() {
   init "/boot/init.d/network.hostname.sh"   # Set the hostname
   init "/boot/init.d/network.ssh.sh"        # Set SSH configuration
   init "/boot/init.d/network.ssh.sh"        # Set SSH settings
   init "/boot/init.d/network.wifi.sh"       # Set WIFI Settings
   init "/boot/init.d/locale.sh"             # Set Keyboard settings

   # Remove init scripts after first successful run
   remove
}

init() {
   local script=$1
   [ -f $script ] || return 0
   "$script" $@
}

remove() {
   # Remove init scripts after first successful run
   rm -f /boot/firstrun.sh
   sed -i 's| systemd.run.*||g' /boot/cmdline.txt
   exit 0
}

main $@ # <-- Bootstrap script