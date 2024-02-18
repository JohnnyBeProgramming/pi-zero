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
    #upgrade
    
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

    # Install required dependencies
    #sudo apt-get install hostapd iptables -y

    # Stop services while we configure them
    sudo systemctl stop hostapd
    sudo systemctl stop dnsmasq

    # Assign static IP in local network for wlan0
    cat <<- EOF > /etc/dhcpcd.conf
interface wlan0
static ip_address=192.168.0.10/24
denyinterfaces eth0
denyinterfaces wlan0
EOF

    # Setup the DHCP server (dnsmaq)
    sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
    #sudo nano /etc/dnsmasq.conf
    cat <<- EOF > /etc/dnsmasq.conf
interface=wlan0
  dhcp-range=192.168.0.11,192.168.0.30,255.255.255.0,24h
EOF

    # Configure the hotspot config (hostpad)
    #sudo nano /etc/hostapd/hostapd.conf
    cat <<- EOF > /etc/hostapd/hostapd.conf
interface=wlan0
bridge=br0
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
ssid=$(hostname)
wpa_passphrase=DangerDanger
EOF
    # Tell the system where to find the config
    #sudo nano /etc/default/hostapd
    echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' >> /etc/default/hostapd

    # Have wlan0 forward via Ethernet cable to your modem.
    # sudo nano /etc/sysctl.conf
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

    # Add IP masquerading for outbound traffic on eth0 using iptable
    sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"
    # Persist ip routing rules on restart
    sed 's|exit 0|iptables-restore < /etc/iptables.ipv4.nat\nexit 0|' /etc/rc.local > /tmp/rc.local
    sudo mv /tmp/rc.local /etc/rc.local
    
    # Pass all traffic between the wlan0 and eth0 interfaces
    sudo brctl addbr br0        # Add bridge br0
    sudo brctl addif br0 eth0   # Connect to en0

    # Add bridge to the network interfaces
    # sudo nano /etc/network/interfaces
    cat <<- EOF > /etc/network/interfaces
auto br0
iface br0 inet manual
bridge_ports eth0 wlan0
EOF

    # Restart the services and start the hotspot
    sudo systemctl start dnsmasq
    #sudo systemctl start hostapd
    sudo systemctl unmask hostapd
    sudo systemctl enable hostapd
    sudo systemctl start hostapd
}

setup $@ # <-- Bootstrap the script