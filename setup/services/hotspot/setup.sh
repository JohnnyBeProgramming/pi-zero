#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
# See also: 
# - https://thepi.io/how-to-use-your-raspberry-pi-as-a-wireless-access-point/
# - https://raspberrypi.stackexchange.com/questions/88438/raspberry-pi-as-access-point-with-captive-portal/106018#106018
# - https://pimylifeup.com/raspberry-pi-captive-portal/
# --------------------------------------------------------------
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

setup() {
    config $@
    
    # Load common setup functions
    source "$THIS_DIR/../utils.sh"
    
    # Install any dependencies used by this service (if not already installed)
    #install-dependencies dnsmasq hostapd iptables bridge-utils ethtool
    sudo apt install -y dnsmasq hostapd iptables
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
    # Assign static IP in local network for wlan0
    # if ! cat /etc/dhcpcd.conf | grep -v '#.*' | grep 'interface wlan0' > /dev/null; then
    #     cat "$THIS_DIR/etc/dhcpcd.conf" | sudo tee -a /etc/dhcpcd.conf > /dev/null
    # fi
    
    # Configure the wireless hotspot config 
    echo "Configuring hotspot: /etc/hostapd/hostapd.conf"
    sudo cp -f "$THIS_DIR/etc/hostapd/hostapd.conf" /etc/hostapd/hostapd.conf    
    if ! cat /etc/default/hostapd | grep -v '#.*' | grep 'DAEMON_CONF=' > /dev/null; then
        # Tell the system where to find the config
        echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' | sudo tee -a /etc/default/hostapd > /dev/null
    fi

    # Setup the DHCP server (dnsmaq)
    echo "Configuring dnsmasq: /etc/dnsmasq.conf"
    sudo cp -f "$THIS_DIR/etc/dnsmasq.conf" /etc/dnsmasq.conf
        
    
    # Have wlan0 forward via Usb/Ethernet cable to your modem.
    if ! cat /etc/sysctl.conf | grep -v '#.*' | grep 'net.ipv4.ip_forward=' > /dev/null; then
        echo "Enable internet forwarding on WLAN."
        echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null
    fi

    # -------------------------------

    # Add IP routing rules if needed
    local ifout=
    local ifopts=("eth0" "usb0" "lo")
    for iface in ${ifopts[@]}; do
        if sudo ifconfig $iface 2> /dev/null > /dev/null; then
            ifout=$iface
            break
        fi
    done
    echo "Outbound interface: ${ifout:-none}"
    if [ ! -z "${ifout:-}" ]; then
        echo "Adding IP routing rules: /etc/iptables.ipv4.nat"

        # Add IP masquerading for outbound traffic on (eth0|usb0) using iptable
        sudo iptables -t nat -A POSTROUTING -o $ifout -j MASQUERADE
        sudo iptables -A FORWARD -i $ifout -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
        sudo iptables -A FORWARD -i wlan0 -o $ifout -j ACCEPT
        sudo iptables-save | sudo tee /etc/iptables.ipv4.nat > /dev/null

        # Pass all traffic between the wlan0 and (eth0|usb0) interfaces
        #sudo brctl addbr br0        # Add bridge br0
        #sudo brctl addif br0 $ifout   # Connect to en0

        # Add bridge to the network interfaces
        #if [ ! -f "/etc/network/interfaces.d/hotspot" ]; then
        #    echo "Bridging network interfaces: /etc/network/interfaces.d/hotspot"
        #    sudo cp -f "$THIS_DIR/etc/network/interfaces.d/hotspot" "/etc/network/interfaces.d/hotspot"    
        #fi
    fi
    
    local wlan_ip=$(cat /etc/dnsmasq.conf | grep listen-address | cut -d '=' -f2)
    if ! cat /etc/rc.local | grep iptables-restore > /dev/null; then
        # Persist ip routing rules on restart
        sed 's|exit 0||' /etc/rc.local | sudo tee /etc/rc.local > /dev/null
        echo 'iptables-restore < /etc/iptables.ipv4.nat' | sudo tee -a /etc/rc.local
        echo 'ifconfig wlan0 '$wlan_ip | sudo tee -a /etc/rc.local
    fi
    # Restore the ip tables into current session
    echo "Load iptables into current session"
    sudo iptables-restore < /etc/iptables.ipv4.nat
    sudo ifconfig wlan0 $wlan_ip

    # Start the hotspot now that the DNS server is running
    echo "Start the wifi hotspot..."
    sudo systemctl unmask hostapd
    sudo systemctl enable hostapd
    sudo systemctl start hostapd

    # Restart the DNS server before starting the hostpot
    echo "Start the dns server..."
    sudo systemctl start dnsmasq

}

setup-captive-portal() {
    sudo apt update
    sudo apt upgrade
    
    sudo apt install -y libmicrohttpd-dev build-essential

    git clone https://github.com/nodogsplash/nodogsplash.git ~/nodogsplash
    cd ~/nodogsplash
    make
    sudo make install
    
    local wlan_ip=$(cat /etc/dnsmasq.conf | grep listen-address | cut -d '=' -f2)
    cat <<- EOF | sudo tee /etc/nodogsplash/nodogsplash.conf > /dev/null
GatewayInterface wlan0
GatewayAddress $wlan_ip
MaxClients 250
AuthIdleTimeout 480
EOF

    sudo nodogsplash
}

setup $@ # <-- Bootstrap the script