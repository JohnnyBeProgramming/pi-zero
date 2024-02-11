# Setting up a Raspberry Pi Zero W

This repository contains automation scripts to deploy a set of payloads to a Raspberri Pi Zero.

The following features are supported:

 - Enable SSH (if not already enabled) and run on system startup
 - Check for internet connection, and update system OS to latest
 - Install developer tools (eg: git, python, sqlite, rust, golang)
 - Install wireless access point tools (eg: to create a wifi hotspot)
 - Install network tools that can be used to capture and analize network packets


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

To simplify and streamline the installation process, we created the `install.sh` 
script, to install required dependencies and setup the pi zero for use.

## Option 1: From your host machine, install over ssh
```bash
cat ./setup/install.sh | ssh admin@respberrypi.local
# <-- Now you should be prompted for the ssh password, then it starts installing
```

## Option 2: On the raspberry pi zero, install from git
```bash
sudo apt install git
git clone --recursive https://github.com/JohnnyBeProgramming/pi-zero.git
sudo ./pi-zero/setup/install.sh
```

