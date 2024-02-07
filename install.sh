#!/usr/bin/env bash
# --------------------------------------------------------------
# This script is used to initialise a (Debian) rasberry pi device,
# and installs:
#  - Latest system updates and patches
#  - Enables SSH for remote connections
#  -
# --------------------------------------------------------------
main() {
    config $@
    enable-ssh
    
    # First we check for an internet connection, and update the OS
    check-internet
    update-os
    
    # Install the required packages onto the raspberry pi
    install-dev-tools
}

config() {
    THIS_DIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)
    HAS_WIFI=$(has-wifi && true || false)
}

enable-ssh() {
    # Enable SSH on the system
    sudo systemctl enable ssh
    sudo systemctl start ssh
}

check-internet() {
    echo "Testing Internet connection and name resolution..."
    if [ "$(curl -s http://www.msftncsi.com/ncsi.txt)" != "Microsoft NCSI" ]; then
        echo "Error: No Internet connection or name resolution doesn't work! Exiting..."
        exit
    fi
    echo "Passed: Internet connection works"
}

has-wifi() {
    if ! iwconfig 2>&1 | grep -q -E ".*wlan0.*"; then
        echo "Warning: Wireless interface 'wlan0' not found"
        exit 1
    fi
    exit 0
}

update-os() {
    sudo apt update
    sudo apt full-upgrade -y
}

install-dev-tools() {
    sudo apt-get -y install git python3-pip python3-dev sqlite3
}

install-access-point() {
    # Create a backup of the original resolve file (before installing dnsmasq)
    if [ ! -f "/tmp/resolv.conf" ]
    then
        echo "Backing up /etc/resolv.conf -> /tmp/resolv.conf" 
        sudo cp /etc/resolv.conf /tmp/resolv.conf
    fi

    # dnsmasq:      Providing Domain Name System (DNS) caching, a Dynamic Host Configuration Protocol (DHCP) server, router advertisement and network boot features
    # hostapd:      User space daemon software enabling a network interface card to act as an access point and authentication server.
    # bridge-utils: The bridge-utils package contains a utility needed to create and manage bridge devices.
    # ethtool:      Query or control network driver and hardware settings
    sudo apt-get -y install dnsmasq hostapd bridge-utils ethtool

    # After install of dnsmasq, the nameserver in /etc/resolv.conf is set to 127.0.0.1, so we replace it with 8.8.8.8
    sudo bash -c "cat /tmp/resolv.conf > /etc/resolv.conf"    
    sudo bash -c "echo nameserver 8.8.8.8 >> /etc/resolv.conf"  # append 8.8.8.8 as fallback secondary dns
}

install-network-tools() {
    # screen:       Screen is a full-screen window manager that multiplexes a physical terminal between several processes (typically interactive shells).
    # inotify-tools The inotify API provides a mechanism for monitoring filesystem events
    # autossh       A program to start a copy of ssh and monitor it, restarting it as necessary should it die or stop passing traffic.
    # bluez:        Bluetooth utilities. http://www.bluez.org/ Utilities for use in Bluetooth applications
    # bluez-tools:  A set of tools to manage Bluetooth devices for Linux.
    # policykit-1:  This is useful for scenarios where a mechanism needs to verify that the operator of the system really is the user or really is an administrative user
    # tshark:       TShark is a network protocol analyzer. It lets you capture packet data from a live network, or read packets from a previously saved capture file
    # tcpdump:      Tcpdump prints out a description of the contents of packets on a network interface that match the boolean expression.
    # iodine:       Lets you tunnel IPv4 data through a DNS server. This can be useful in situations where Internet access is firewalled, but DNS queries are allowed.
    sudo apt-get -y install screen inotify-tools autossh bluez bluez-tools policykit-1 tshark tcpdump iodine
}


# Bootstrap the script
main $@