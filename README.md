# Club404 - Raspberry Pi

This repository contains the required scripts and setup needed to deploy the tool to a Raspberri Pi.


## Converting Rasberri pi image to QEMU `qcow`

```bash
export KERNEL_URL=https://raw.githubusercontent.com/dhruvvyas90/qemu-rpi-kernel/master/kernel-qemu-4.4.34-jessie
export KERNEL_PATH=./images/kernel-qemu-4.4.34-jessie
export PI_IMAGE=./images/raspios-lite.img.xz
export PI_QCOW=./images/raspios-lite.qcow

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
