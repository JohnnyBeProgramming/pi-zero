  1. Download the Raspbian Lite image from https://downloads.raspberrypi.org/raspbian_lite_latest (add .torrent to get a torrent)

  2. Unzip the download to extract the .img file

  3. Insert a FAT32-formatted SD card, and copy the image over:
      - `diskutil list` to identify the disk number, e.g. `/dev/disk2`
      - `diskutil unmountDisk /dev/disk2`
      - `sudo dd bs=1m if=image.img of=/dev/rdisk2`

  4. Before unmounting, edit a couple of files to activate internet-over-USB.  The image mounted for me at `/Volumes/boot`.
      - In `config.txt`, add this as the last line of the file: `dtoverlay=dwc2`
        ```bash
        # File: /Volumes/bootfs/cmdline.txt
        BOOT_FILE="/Volumes/bootfs/cmdline.txt"
        BOOT_ARGS=("dtoverlay=dwc2")
        for feat in $BOOT_ARGS; do \
          grep "$feat" $BOOT_FILE > /dev/null || sed "s|\$| $feat|" $BOOT_FILE; \
        done
        ```
      - In `cmdline.txt`, add this as a parameter, just after the `rootwait` parameter: `modules-load=dwc2,g_ether`
        ```bash
        # File: /Volumes/bootfs/cmdline.txt
        BOOT_FILE="/Volumes/bootfs/cmdline.txt"
        BOOT_FEAT="modules-load=dwc2,g_ether"
        grep "$BOOT_FEAT" $BOOT_FILE > /dev/null || sed "s|rootwait|rootwait $BOOT_FEAT|" $BOOT_FILE
        ```
  5. Unmount the SD card (via Finder) and stick it in the Raspberry Pi.

  6. Attach a USB cable from your Mac to the RPi via the "USB" port on the RPi.  This should power the RPi, and it will start to boot up.

  7. Give it a few minutes to boot. Open the Network preference panel (System Preferences -> Network) on your Mac, and you should see a new networking device called something like "RNDIS/Ethernet Gadget".  For now it should be set to "Configure via DHCP" - it will have a link-local address.

  8. Once the RPi boots, you should be able to SSH to it with `ssh pi@raspberrypi.local`.  The password is `raspberry`.

  9. Over SSH, edit `/etc/network/interfaces` to add a USB interface - add the following lines:
```
  allow-hotplug usb0
  iface usb0 inet static
      address 192.168.2.2
      netmask 255.255.255.0
      gateway 192.168.2.1
```
  10. Next, set up `resolv.conf` to use `192.168.2.1` for name resolution - edit `/etc/resolvconf.conf`, and uncomment/edit the `nameservers` line to read `nameservers=192.168.2.1`.
  11. Finally, on your Mac, configure the RNDIS/Ethernet Gadget interface with the following parameters:
    - Configure IPV4: `Manually`
    - IP Address: `192.168.2.1`
    - Subnet Mask: `255.255.255.0`
    - Router: (none)
    - Under Advanced -> DNS, add your favorite DNS server, like `8.8.8.8` or your home router.
  12. Under the "Sharing" preferences pane, turn on Internet Sharing, and share your Mac's active network connection with the RNDIS/Ethernet Gadget interface.
  13. Reboot the RPi.  After it comes back up, you should still be able to connect via `ssh pi@raspberrypi.local`, and the device should now have the IP address `192.168.2.2` and access to the Internet!