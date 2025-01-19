# Automated Setup Script

To simplify and automate the setup of your pi image, use the setup script:

```bash
cd docs/pi-zero-setup

./setup.sh 
```

# Step by step instructions

  1. Download the Raspbian Lite image from https://downloads.raspberrypi.org/raspbian_lite_latest (add .torrent to get a torrent)
```bash
# Download the latest image
export RPI_IMAGE_URL="https://downloads.raspberrypi.org/raspbian_lite_latest"
export RPI_IMAGE_PATH="./images/$(basename $RPI_IMAGE_URL)"
mkdir -p "$RPI_IMAGE_PATH"
curl -Lo "$RPI_IMAGE_PATH.zip" "$RPI_IMAGE_URL"
```

  2. Unzip the download to extract the .img file
```bash
# Extract image and move to predictable location
tar -xvzf "$RPI_IMAGE_PATH.zip" -C "$RPI_IMAGE_PATH"
cp -f "$(find "$RPI_IMAGE_PATH" -name '*.img' | head -n 1)" "./images/current.img"
rm -rf "$RPI_IMAGE_PATH"
```

  3. Insert a FAT32-formatted SD card, and copy the image over:
      - `diskutil list` to identify the disk number, e.g. `/dev/disk4`
```bash
# diskutil list | grep "(external, physical)" | awk '{print $1}'
export RPI_IMAGE_DISK="/dev/disk4"
diskutil unmountDisk "$RPI_IMAGE_DISK"
sudo dd bs=1m if=./images/current.img of=$RPI_IMAGE_DISK
```

  4. Before unmounting, edit a couple of files to activate internet-over-USB. The image mounted for me at `/Volumes/boot`.

      - In `config.txt`, add this as the last line of the file: `dtoverlay=dwc2`
      - In `cmdline.txt`, add this just after the `rootwait`: `modules-load=dwc2,g_ether`
```bash
export RPI_BOOT_PATH="/Volumes/boot"

if ! grep -q "dtoverlay=dwc2" "$RPI_BOOT_PATH/config.txt"; then
  echo "dtoverlay=dwc2" >> "$RPI_BOOT_PATH/config.txt"
fi

if ! grep -q "modules-load=dwc2,g_ether" "$RPI_BOOT_PATH/cmdline.txt"; then  
  sed -i '' "s|rootwait|rootwait modules-load=dwc2,g_ether|" "$RPI_BOOT_PATH/cmdline.txt"
fi
```

  5. Unmount the SD card (or do it via Finder) and stick it in the Raspberry Pi.
```bash
export RPI_IMAGE_DISK="/dev/disk4"
diskutil unmountDisk "$RPI_IMAGE_DISK"
```

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