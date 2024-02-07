# Club404 - Raspberry Pi

This repository contains the required scripts and setup to deploy the tools to a Raspberri Pi.

# Prerequisites

We assume you have the following:

 - Raspberri Pi with a wireless network card (eg: Raspberry Pi Zero)
 - The device is connected to the internet and/or your locaal network
 - Valid SSH credentials and hostname is available and ready to conect

# Installation steps

To simplify and streamline the installation, the `install.sh` was created,
and this script will install all the required tools we need on the device:

 - Enable SSH (if not already enabled) and run on system startup
 - Check for internet connection, and update system OS to latest
 - Install developer tools (eg: git, python, sqlite)
 - Install wireless access point tools (eg: to create a wifi hotspot)
 - Install network tools that can be used to capture and analize network packets

Once you have the raspberri pi connected to the network, and the hostname is known, 
we can securely copy the installation file like so:

```bash
# Copy the installation file to the remote device'es home dir
scp ./install.sh admin@club404.local:.

# Connect to the device using SSH
ssh admin@club404.local
# <-- Now you should be connected to device terminal, then run:
# admin@club404: ./install.sh
```

### Converting Rasberri pi image to QEMU `qcow`

```bash
export KERNEL_URL=https://raw.githubusercontent.com/dhruvvyas90/qemu-rpi-kernel/master/kernel-qemu-4.4.34-jessie
export KERNEL_PATH=./images/kernel-qemu-rpi
export PI_IMAGE=./images/base.img.xz
export PI_QCOW=./images/base.qcow

# Fetch the kernal
curl -ks -o $KERNEL_PATH $KERNEL_URL

# Convert pi image disk to usable format
qemu-img convert -f raw -O qcow2 $PI_IMAGE $PI_QCOW


sudo qemu-system-arm \
  -kernel $KERNEL_PATH \
  -append "root=/dev/sda2 panic=1 rootfstype=ext4 rw" \
  -hda $PI_QCOW \
  -cpu arm1176 -m 256 \
  -M versatilepb \
  -no-reboot \
  -serial stdio \
  -net nic -net user \
  #-net tap,ifname=vnet0,script=no,downscript=no
```
