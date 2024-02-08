# Club404 - Raspberry Pi

This repository contains the required scripts and setup to deploy some tools to a Raspberri Pi.

# Prerequisites

We assume you have the following:

 - Raspberri Pi with a wireless network card (eg: Raspberry Pi Zero)
 - The device is connected to the internet and/or your locaal network
 - Valid SSH credentials and hostname is available and ready to conect

```bash
# You can test your ssh connection to the pi with this command
ssh admin@respberrypi.local whoami
```

# Installation steps

To simplify and streamline the installation, the `install.sh` was created
to allow us to automate most of the setup of the pi zero.

## Option 1: From your host machine, install over ssh
```bash
cat ./install.sh | ssh admin@respberrypi.local
# <-- Now you should be prompted for the ssh password, then it starts installing
```

## Option 2: On the raspberry pi zero, install from git
```
sudo apt install git
git clone https://github.com/JohnnyBeProgramming/pi-zero.git
sudo ./pi-zero/install.sh
```

This script will install all the required tools we need on the device:

 - Enable SSH (if not already enabled) and run on system startup
 - Check for internet connection, and update system OS to latest
 - Install developer tools (eg: git, python, sqlite, rust, golang)
 - Install wireless access point tools (eg: to create a wifi hotspot)
 - Install network tools that can be used to capture and analize network packets

