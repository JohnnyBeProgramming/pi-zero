#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

setup() {
    config $@
    
    # Load common setup functions
    source "$THIS_DIR/../utils.sh"
    
    # Install any dependencies used by this service (if not already installed)
    install-dependencies dnsmasq hostapd iptables bridge-utils ethtool
    upgrade
    
    # Recreate the service manifest and update to latest
    #install-service $SETUP_NAME "$HOME/.hotspot"
}

config() {
    # Declare gobal ENV vars for setup
    export SETUP_NAME=${1:-"$(basename $THIS_DIR)"}
    export SETUP_PATH=${2:-$THIS_DIR}
}

upgrade() {
    # See also: https://thepi.io/how-to-use-your-raspberry-pi-as-a-wireless-access-point/

    # Stop services while we configure them
    sudo systemctl stop hostapd || true
    sudo systemctl stop dnsmasq || true
    
    # Assign static IP in local network for wlan0
    if ! cat /etc/dhcpcd.conf | grep -v '#.*' | grep 'interface wlan0' > /dev/null; then
        cat "$THIS_DIR/etc/dhcpcd.conf" | sudo tee -a /etc/dhcpcd.conf > /dev/null
    fi
    
    # Setup the DHCP server (dnsmaq)
    if [ ! -f /etc/dnsmasq.conf ]; then
        echo "Configuring dnsmasq: /etc/dnsmasq.conf"
        sudo cp -f "$THIS_DIR/etc/dnsmasq.conf" /etc/dnsmasq.conf
    fi
    
    # Configure the hotspot config (hostpad)
    if [ ! -f /etc/hostapd/hostapd.conf ]; then
        echo "Configuring hotspot: /etc/hostapd/hostapd.conf"
        sudo cp -f "$THIS_DIR/etc/hostapd/hostapd.conf" /etc/hostapd/hostapd.conf
        
        # Tell the system where to find the config
        echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' | sudo tee -a /etc/default/hostapd > /dev/null
    fi
    
    # Have wlan0 forward via Ethernet cable to your modem.
    if ! cat /etc/sysctl.conf | grep -v '#.*' | grep 'net.ipv4.ip_forward=' > /dev/null; then
        echo "Enable internet forwarding on WLAN."
        echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null
    fi
    
    # Add IP routing rules if needed
    local ifout=
    local ifopts=("eth0" "usb0" "lo")
    for iface in ${ifopts[@]}; do
        if ifconfig $iface 2> /dev/null > /dev/null; then
            ifout=$iface
            break
        fi
    done
    echo "Outbound interface: $ifout"
    if [ ! -z "${ifout:-}" ] && [ ! -f "/etc/iptables.ipv4.nat" ]; then
        echo "Adding IP routing rules: /etc/iptables.ipv4.nat"

        # Add IP masquerading for outbound traffic on (eth0|usb0) using iptable
        sudo iptables -t nat -A POSTROUTING -o $ifout -j MASQUERADE
        sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"
        
        # Persist ip routing rules on restart
        sed 's|exit 0|iptables-restore < /etc/iptables.ipv4.nat\nexit 0|' /etc/rc.local | sudo tee /etc/rc.local > /dev/null
        
        # Pass all traffic between the wlan0 and (eth0|usb0) interfaces
        sudo brctl addbr br0        # Add bridge br0
        sudo brctl addif br0 $ifout   # Connect to en0
    fi
    
    # Add bridge to the network interfaces
    if [ ! -f "/etc/network/interfaces.d/hotspot" ]; then
        echo "Bridging network interfaces: /etc/network/interfaces.d/hotspot"
        sudo cp -f "$THIS_DIR/etc/network/interfaces.d/hotspot" "/etc/network/interfaces.d/hotspot"    
    fi
    
    # Restart the services and start the hotspot
    sudo systemctl start dnsmasq
    #sudo systemctl start hostapd
    sudo systemctl unmask hostapd
    sudo systemctl enable hostapd
    sudo systemctl start hostapd
}

setup $@ # <-- Bootstrap the script