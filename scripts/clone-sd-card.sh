#!/usr/bin/env bash
# See also: https://medium.com/@andersonpem/utm-on-apples-m1-file-sharing-with-debian-11-xfce-c5a262e27188

# Enable SSH on the system
if [ -z $1 ] || [ -z $2 ]
then
    echo "Please specify the volume to clone and the target destination."
    echo "eg: $0 /dev/disk4 ~/Desktop/dump.img"
    [ ! -z $1 ] || diskutil list external
    exit 0
fi

# Make a clone of the specified drive
if which qemu-img > /dev/null
then
    echo "Creating a new disk image: $2"
    dd if=$1 of=$2
else
    echo "Cannot find disk utility 'dd' on local machine"
    exit 1
fi

# Convert to image for QEMU (UTM) virtualisation
if which qemu-img > /dev/null
then
    echo "Converting to a VM image: $2.qcow2"
    qemu-img convert -f raw -O qcow2 $2 $2.qcow2
fi