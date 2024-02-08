#!/usr/bin/env bash
# --------------------------------------------------------------
# This script is used to initialise a (Debian) rasberry pi device,
# and installs the following:
#  - Latest system updates and patches
#  - Enables SSH for remote connections
#  - Developer tools such as python, node, golang and rust
#  - Some tools used for network mapping and DNS lookup
#  - Software to turn the device into an access point
# --------------------------------------------------------------
main() {
    # Setup basic config and enable SSH (if not already activated)
    config $@
    enable-ssh
    
    # First we check for an internet connection, and update the OS
    check-internet
    update-os
    
    # Install the required packages onto the raspberry pi
    install-dev-tools
    #install-opsec-tools
    # install-access-point
    # install-network-tools
    # install-cryptographics
    
    # Setup and configure system as a wireless access point
    # disable-unused-services
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
    sudo apt-get -y install git sqlite3
    
    # Install Python v3
    sudo apt-get -y install python3-pip python3-dev
    
    # Install NodeJS
    if ! which npm > /dev/null
    then
        sudo apt install -y nodejs npm
        sudo npm install --global yarn
    fi
    
    # Install golang
    #sudo apt-get install golang
    install-golang-latest
    
    # Install rust
    if ! which cargo > /dev/null
    then
        curl https://sh.rustup.rs -sSf | bash -s -- -y
    fi
}

upgrade-python-version() {
    local tag="3.11.5"
    local bin="python3.11"

    if [ ! -f /usr/local/bin/$bin ]
    then
        wget https://www.python.org/ftp/python/$tag/Python-$tag.tgz
        tar -zxvf Python-$tag.tgz
        cd Python-$tag
        ./configure --enable-optimizations
        sudo make altinstall
        cd ..
        rm -rf Python-$tag
        rm -f Python-$tag.tgz

        pushd /usr/bin > /dev/null
        sudo rm python
        sudo ln -s /usr/local/bin/$bin python
        popd /dev/null
    fi

install-golang-latest() {
    local tag="1.21.4"
    local arch=$(uname -m)
    if ! go version | grep $tag > /dev/null
    then
        wget https://go.dev/dl/go$tag.linux-$arch.tar.gz
        sudo tar -C /usr/local -xzf go$tag.linux-$arch.tar.gz
        rm go$tag.linux-$arch.tar.gz
    fi

    if ! cat ~/.profile | grep GOPATH > /dev/null:
    then
        cat << EOF >> ~/.profile
GOPATH="\$HOME/go"
PATH="\$GOPATH/bin:/usr/local/go/bin:\$PATH"
EOF
    fi
    source ~/.profile
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
    # dnsutils:     A collection of dns utilities, such as nslookup and dig for quering DNS information
    # screen:       Screen is a full-screen window manager that multiplexes a physical terminal between several processes (typically interactive shells).
    # inotify-tools The inotify API provides a mechanism for monitoring filesystem events
    # autossh       A program to start a copy of ssh and monitor it, restarting it as necessary should it die or stop passing traffic.
    # bluez:        Bluetooth utilities. http://www.bluez.org/ Utilities for use in Bluetooth applications
    # bluez-tools:  A set of tools to manage Bluetooth devices for Linux.
    # policykit-1:  This is useful for scenarios where a mechanism needs to verify that the operator of the system really is the user or really is an administrative user
    # tshark:       TShark is a network protocol analyzer. It lets you capture packet data from a live network, or read packets from a previously saved capture file
    # tcpdump:      Tcpdump prints out a description of the contents of packets on a network interface that match the boolean expression.
    # iodine:       Lets you tunnel IPv4 data through a DNS server. This can be useful in situations where Internet access is firewalled, but DNS queries are allowed.
    sudo apt-get -y install dnsutils screen inotify-tools autossh bluez bluez-tools policykit-1 tshark tcpdump iodine
}

install-cryptographics() {
    # pycrypto:     Python Cryptography Toolkit (pycrypto). This is a collection of both secure hash functions (such as SHA256 and RIPEMD160), and various encryption algorithms
    # pydispatcher: PyDispatcher provides the Python programmer with a multiple-producer-multiple-consumer signal-registration and routing infrastructure
    sudo pip install pycrypto
    sudo pip install pydispatcher
}

install-opsec-tools() {
    # nmap:         Nmap ("Network Mapper") is an open source tool for network exploration and security auditing. 
    # dirbuster:    DirBuster is a multi threaded java application designed to brute force directories and files names on web/application servers.
    # gobuster:     Discover directories and files that match in the wordlist (written on golang)
    sudo apt install -y nmap gobuster #dirbuster

    # Install hugo (static site generator)
    sudo apt install -y hugo

    # Install taskfile as a golang package
    go install github.com/go-task/task/v3/cmd/task@latest    
}

install-wordlist() {
    git clone https://gitlab.com/kalilinux/packages/dirbuster.git /opt/lists
}

install-linpeas() {
    local LINPEAS_URL=https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh
    mkdir -p /opt/tools/
    curl -L $LINPEAS_URL > /opt/tools/linpeas.sh
    chmod +x /opt/tools/linpeas.sh
}

disable-unused-services() {
    echo "Disabeling unneeded services to shorten boot time ..."
    sudo update-rc.d ntp disable # not needed for stretch (only jessie)
    sudo update-rc.d avahi-daemon disable
    sudo update-rc.d dhcpcd disable
    sudo update-rc.d networking disable
    sudo update-rc.d avahi-daemon disable
    sudo update-rc.d dnsmasq disable # we start this by hand later on
}

setup-hid-devices() {
    echo "Create udev rule for HID devices..."
    # rule to set access rights for /dev/hidg* to 0666
    echo 'SUBSYSTEM=="hidg",KERNEL=="hidg[0-9]", MODE="0666"' > /tmp/udevrule
    sudo bash -c 'cat /tmp/udevrule > /lib/udev/rules.d/99-usb-hid.rules'
}

build-rustscan() {
    pushd /tmp > /dev/null
    git clone https://github.com/RustScan/RustScan.git
    cd ./RustScan && cargo build --release
    mv ./target/release/rustscan /usr/local/bin/rustscan
    popd > /dev/null
}

create-usb-image() {
    # create 128 MB image for USB storage
    echo "Creating 128 MB image for USB Mass Storage emulation"
    mkdir -p $THIS_DIR/USB_STORAGE
    dd if=/dev/zero of=$THIS_DIR/USB_STORAGE/image.bin bs=1M count=128
    mkdosfs $THIS_DIR/USB_STORAGE/image.bin
}

# Bootstrap the script
main $@