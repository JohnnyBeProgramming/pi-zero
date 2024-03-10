# Setting up a Raspberry Pi Zero W

This repository contains automation scripts to deploy payloads to a Raspberri Pi Zero.

The following features are supported:

 - Modify raspberry boot image to enable ethernet over USB data cable
 - Install developer tools (eg: git, python, sqlite, rust, golang)
 - Install wireless access point tools (eg: to create a wifi hotspot)


# Prerequisites

We assume you have the following:

 - Raspberri Pi Zero, with a wireless network card
 - The device is connected to the internet and/or your locaal network
 - Valid SSH credentials and hostname is available and ready to conect

```bash
# You can test your ssh connection to the pi with this command
ssh admin@respberrypi.local whoami
```


# Installation steps

Broadly speaking, there are a few steps required to set up your raspberry pi:

 1) Burn a new raspios image to an SD card (we used `raspios-bullseye-armhf-lite.img`)
 2) Configure SSH access over a USB/Eternet data cable (attached to your host)
 3) Detach SD card and boot up raspberry pi with the new SD card (this might take a while)
 4) Once the device is online and ready, remotely deploy setup using `ssh` and install

To simplify and streamline the installation process, we created the `deploy.sh` 
script, to install required dependencies and setup the pi zero for use.

```bash
./setup/deploy.sh user@respberrypi.local
# <-- Now you should be prompted for the ssh password, then it starts installing
```

Alternatively, if you have direct access through a keyboard and terminal, you can install using git:

```bash
sudo apt install git
git clone --recursive https://github.com/JohnnyBeProgramming/pi-zero.git
sudo ./pi-zero/setup/install.sh
```



# Install using nix

Nix is a very powerfull tool to manage package dependencies on any 
operating system, including Raspberry Pi's. Using nix, we can also 
automatically build pre-configured images that we can burn directly 
to an SD image, ready to boot in our pi.

```bash
# Build the setup packages
nix-build -A setup

# Start a local shell with dependencies installed
nix-shell
```
