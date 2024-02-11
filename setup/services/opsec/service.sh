#!/bin/sh
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
# This script starts a system service rasberry pi device
# --------------------------------------------------------------
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

config() {
    OPSEC_USER=${OPSEC_USER:-"admin"}
    OPSEC_DIR=${OPSEC_DIR:-"/home/$OPSEC_USER/app"}
    OPSEC_LANG=${OPSEC_LANG:-$LANG}
    OPSEC_FILE=$OPSEC_DIR/.profile

    
    # Load the basic config (if present)
    if [ -f $THIS_DIR/service.env ]
    then
        echo "[ opsec ] Loading config: $THIS_DIR/service.env"
        source $THIS_DIR/service.env
    else
        echo "[ opsec ] Warning: No config found at $THIS_DIR/service.env"
    fi
    
    # Create bash script which could be altered from /home/admin/.profile
    # --------------------------------------------------------------
    echo "[ opsec ] Profile $OPSEC_FILE"
	cat << EOF > $OPSEC_FILE
#!/bin/bash
OPSEC_DIR=$OPSEC_DIR
OPSEC_LANG=$OPSEC_LANG

$(declare -f onLogin)
EOF
    chown $OPSEC_USER:$OPSEC_USER $OPSEC_FILE
    # --------------------------------------------------------------

	# trigger callback for on boot finished
	(
		declare -f onBootFinished > /dev/null && echo "Boot of application finished" # run only once
	)&

}

run() {
	echo "========================= OpSec tools starting up ======================"
    config $@ # Load config settings
	
	# Initialise all the modules
	usb-init
    wifi-init

	# Post installation advice
	echo
	echo "===================================================================================="
	echo "If you came till here without errors, you shoud be good to go with your device!"
	echo "...if not, you're on your own. This comes with no guarantees."
	echo ""
	echo "If you use a USB OTG adapter to attach a keyboard, the Pi boots interactive mode."
    echo ""
	echo "Attach this Raspberry Pi to a host computer (via USB data port), to be able to:"
    echo " - Share host internet and ethernet features (via RNDIS/CDC ECM)"
    echo " - SSH into the device with: admin@172.16.0.1 (where 'admin' is your user)"
	echo ""
	echo "If you're using a Pi Zero W, a WiFi AP should also be opened."
    echo " - You could use the AP to connect to the device"
	echo " - Via Bluetooth NAP: admin@172.26.0.1"
	echo ""
	echo "You need to reboot the Pi now!"
	echo "===================================================================================="
}

wifi-check() {
    if ! iwconfig 2>&1 | grep -q -E ".*wlan0.*"; then
        echo "...[Error] no wlan0 interface found"
        return 1
    fi
    return 0
}

wifi-init() {
    echo "[ opsec ] Checking for WiFi capabilities..."

    if wifi-check; then
        echo "[ opsec ] Seems WiFi module is present!"

        if [ ! -z "${WIFI_REG:-}" ]; then
            iw reg set $WIFI_REG || FAILED=true
        fi
		if ${FAILED:-false}; then
			echo "[ opsec ] Failed to configure WiFi zone!"
			return 1
		fi
        
        # start WIFI client
        if [ "${WIFI_CLIENT:-}" == "true" ]; then
            # try to connect to existing WiFi according to the config
            sleep 1 # pause to make new reg domain accessible in scan
            if wifi-client-start; then
                WIFI_CLIENT_CONNECTION_SUCCESS=true
            else
                echo "[ opsec ] Join present WiFi didn't succeed, failing over to access point mode"
                WIFI_CLIENT_CONNECTION_SUCCESS=false
            fi
        fi
        
        # start ACCESS POINT if needed
        # - if WiFi client mode is disabled and ACCESPOINT mode is enabled
        # - if WiFi client mode is enabled, but failed and ACCESPOINT mode is enabled
        if [ "${WIFI_ACCESSPOINT:-}" == "true" ] && ( ! ${WIFI_CLIENT_CONNECTION_SUCCESS:-false} || ! ${WIFI_CLIENT:-false}); then
            wifi-access-point-start
            
            # check if acces point is up and trigger callback
            # Warning!!! This uses the SSID and isn't tested against hidden SSID configurations
            (
                AP_DOWN=true
                while $AP_DOWN; do
                    iw dev | grep -q -E "ssid $WIFI_ACCESSPOINT_NAME"; res=$?
                    if [ $res == 0 ]; then
                        AP_DOWN=false                        
                        declare -f onAccessPointUp > /dev/null && onAccessPointUp # run only once
                    fi
                done
            )&
        fi
    fi
}

wifi-client-start() {
    sudo ifconfig wlan0 up
    
    if $WIFI_CLIENT; then
        echo "Try to find WiFi $WIFI_CLIENT_SSID"
        res=$(wifi-client-scan-essid "$WIFI_CLIENT_SSID")
        if [ "$res" == "WPA2_PSK" ]; then
            echo "Network $WIFI_CLIENT_SSID found"
            echo "... creating config"
            wifi-client-generate-wpa-supplicant-conf "$WIFI_CLIENT_SSID" "$WIFI_CLIENT_PSK"
            echo "... connecting ..."
            wifi-client-start-wpa-supplicant
            return 0
        else
            echo "Network $WIFI_CLIENT_SSID not found"
            return 1 # indicate error
        fi
    else
        return 1 # indicate error
    fi
}
wifi-client-scan-essid() {
	# scan for given ESSID, needs root privs (sudo appended to allow running from user pi if needed)
	scanres=$(sudo iwlist wlan0 scan essid "$1")

	if (echo "$scanres" | grep -q -e "$1\""); then # added '"' to the end to avoid partial match
		#network found

		# check for WPA2
		if (echo "$scanres" | grep -q -e "IE: IEEE 802.11i/WPA2 Version 1"); then
			# check for PSK CCMP
			if (echo "$scanres" | grep -q -e "CCMP" && echo "$scanres" | grep -q -e "PSK"); then
				echo "WPA2_PSK" # confirm WPA2 usage
			else
				echo "WPA2 no CCMP PSK"
			fi
		fi

	else
		echo "Network $1 not found"
	fi
}
wifi-client-generate-wpa-supplicant-conf() {
	# generates temporary configuration (sudo prepended to allow running from user pi if needed)
	sudo bash -c "cat /etc/wpa_supplicant/wpa_supplicant.conf > /tmp/wpa_supplicant.conf"

	# ToDo: check if configured WiFi ESSID already exists,
	# if
	#	WIFI_CLIENT_STORE_NETWORK == true
	#	WIFI_CLIENT_OVERWRITE_PSK == true
	# delete the network entry, to overwrite in the next step
	#
	# if
	#	WIFI_CLIENT_STORE_NETWORK == false
	# delete the network entry, to overwrite the old entry in next step (but don't store it later on)

	wifi-client-generate-wpa-entry "$1" "$2" > /tmp/current_wpa.conf
	sudo bash -c 'cat /tmp/current_wpa.conf >> /tmp/wpa_supplicant.conf'

	# ToDo: store the new network back to persistent config
	# if
	#	WIFI_CLIENT_STORE_NETWORK == true
	# cat /tmp/wpa_supplicant.conf > /etc/wpa_supplicant/wpa_supplicant.conf # store config change
}
wifi-client-generate-wpa-entry() {
	#wpa_passphrase $1 $2 | grep -v -e "#psk"
	# output result only if valid password was used (8..63 characters)
	res=$(wpa_passphrase "$1" "$2") && echo "$res" | grep -v -e "#psk"
}
wifi-client-start-wpa-supplicant() {
	# sudo is unneeded, but prepended in case this should be run without root

	# start wpa supplicant as deamon with current config
	sudo wpa_supplicant -B -i wlan0 -c /tmp/wpa_supplicant.conf

	# start DHCP client on WiFi interface (daemon, IPv4 only)
	sudo dhclient -4 -nw -lf /tmp/dhclient.leases wlan0
}

wifi-access-point-start() {
	wifi-access-point-hostapd-conf

	hostapd -d /tmp/hostapd.conf > /tmp/hostapd.log &

	# configure interface
	ifconfig wlan0 $WIFI_ACCESSPOINT_IP netmask $WIFI_ACCESSPOINT_NETMASK

	# start DHCP server (second instance if USB over Etherne is in use)
	wifi-access-point-dnsmasq-wifi-conf
	dnsmasq -C /tmp/dnsmasq_wifi.conf
}
wifi-access-point-hostapd-conf() {
	cat <<- EOF > /tmp/hostapd.conf
		# This is the name of the WiFi interface we configured above
		interface=wlan0

		# Use the nl80211 driver with the brcmfmac driver
		driver=nl80211

		# This is the name of the network
		ssid=$WIFI_ACCESSPOINT_NAME

		# Use the 2.4GHz band
		hw_mode=g

		# Use channel 6
		channel=$WIFI_ACCESSPOINT_CHANNEL

		# Enable 802.11n
		ieee80211n=1

		# Enable WMM
		wmm_enabled=1

		# Enable 40MHz channels with 20ns guard interval
		ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]

		# Accept all MAC addresses
		macaddr_acl=0

EOF

	if $WIFI_ACCESSPOINT_HIDE_SSID; then
	cat <<- EOF >> /tmp/hostapd.conf
		# Require clients to know the network name
		ignore_broadcast_ssid=2

EOF
	else
	cat <<- EOF >> /tmp/hostapd.conf
		# Require clients to know the network name
		ignore_broadcast_ssid=0

EOF
	fi

	if $WIFI_ACCESSPOINT_AUTH; then
	cat <<- EOF >> /tmp/hostapd.conf
		# Use WPA authentication
		auth_algs=1

		# Use WPA2
		wpa=2

		# Use a pre-shared key
		wpa_key_mgmt=WPA-PSK

		# The network passphrase
		wpa_passphrase=$WIFI_ACCESSPOINT_PSK

		# Use AES, instead of TKIP
		rsn_pairwise=CCMP
EOF
	else
	cat <<- EOF >> /tmp/hostapd.conf
		# Both open and shared auth
		auth_algs=3
EOF
	fi
}
wifi-access-point-dnsmasq-wifi-conf() {
	if $WIFI_ACCESSPOINT_DNS_FORWARD; then
		DNS_PORT="53"
	else
		DNS_PORT="0"
	fi

	cat <<- EOF > /tmp/dnsmasq_wifi.conf
		bind-interfaces
		port=$DNS_PORT
		interface=wlan0
		listen-address=$WIFI_ACCESSPOINT_IP
		dhcp-range=$WIFI_ACCESSPOINT_DHCP_RANGE,$WIFI_ACCESSPOINT_NETMASK,5m
EOF

	if $WIFI_ACCESSPOINT_DHCP_BE_GATEWAY; then
		cat <<- EOF >> /tmp/dnsmasq_wifi.conf
			# router
			dhcp-option=3,$WIFI_ACCESSPOINT_IP
EOF
	else
		cat <<- EOF >> /tmp/dnsmasq_wifi.conf
			# router
			dhcp-option=3
EOF
	fi

	if $WIFI_ACCESSPOINT_DHCP_BE_DNS; then
		cat <<- EOF >> /tmp/dnsmasq_wifi.conf
			# DNS
			dhcp-option=6,$WIFI_ACCESSPOINT_IP
EOF
	else
		cat <<- EOF >> /tmp/dnsmasq_wifi.conf
			# DNS
			dhcp-option=6
EOF
	fi

		# NETBIOS NS
		#dhcp-option=44,$WIFI_ACCESSPOINT_IP
		#dhcp-option=45,$WIFI_ACCESSPOINT_IP

	cat <<- EOF >> /tmp/dnsmasq_wifi.conf

		dhcp-leasefile=/tmp/dnsmasq_wifi.leases
		dhcp-authoritative
		log-dhcp
EOF
}

usb-init() {
	# early out if OpSec is used in OTG mode
	if [ -f /sys/kernel/debug/20980000.usb/state ] && grep -q "DCFG=0x00000000" /sys/kernel/debug/20980000.usb/state; then
		echo "[ opsec ] Detected to run in Host (interactive) mode, we abort device setup now!"
		exit
	else
		echo "[ opsec ] Not an USB gadget, continue..."
	fi


	# check if ethernet over USB should be used
	if ${USB_RNDIS:-} || ${USB_ECM:-}; then
		USB_ETHERNET=true
	fi

	# if ethernet over USB is in use, detect active interface and start DHCP (all as background job)
	if $USB_ETHERNET; then
		usb-ethernet-init
	fi
}
usb-ethernet-init() {
	echo "[ opsec ] Initializing Ethernet over USB..."
    (
        usb-ethernet-active-interface
        
        if [ "$active_interface" != "none" ]; then
            usb-ethernet-create-dhcp-config
            dnsmasq -C /tmp/dnsmasq_usb_eth.conf
            
            # callback onNetworkUp() of payload script
            declare -f onNetworkUp > /dev/null && onNetworkUp
            
            # wait for client to receive DHCP lease
            target_ip=""
            while [ "$target_ip" == "" ]; do
                target_ip=$(cat /tmp/dnsmasq.leases | cut -d" " -f3)
                target_name=$(cat /tmp/dnsmasq.leases | awk '{print $4}')
                sleep 0.2
            done
            
            # callback onNetworkGotIP() of payload script
            declare -f onTargetGotIP > /dev/null && onTargetGotIP
        fi
    )&
}
usb-ethernet-active-interface() {
	# Waiting for one of the interfaces to get a link (either RNDIS or ECM)
	#    loop count is limited by $RETRY_COUNT_LINK_DETECTION, to continue execution if this is used 
	#    as blocking boot script
	#    note: if the loop count is too low, windows may not have enough time to install drivers

	# ToDo: check if operstate could be used for this, without waiting for carrieer
	active_interface="none"

	# if RNDIS and ECM are active check which gets link first
	# Note: Detection for RNDIS (usb0) is done first. In case it is active, link availability
	#	for ECM (usb1) is checked anyway (in case both interfaces got link). This is done
	#	to use ECM as prefered interface on MacOS and Linux if both, RNDIS and ECM, are supported.
	if ${USE_RNDIS:-} && ${USE_ECM:-}; then
		# bring up both interfaces to check for physical link
		ifconfig usb0 up
		ifconfig usb1 up 

		echo "CDC ECM and RNDIS active. Check which interface has to be used via Link detection"
		while [ "$active_interface" == "none" ]; do
		#while [[ $count -lt $RETRY_COUNT_LINK_DETECTION ]]; do
			printf "."

			if [ -f /sys/class/net/usb0/carrier ] && [[ $(</sys/class/net/usb0/carrier) == 1 ]]; then
				# special case: macOS/Linux Systems detecting RNDIS should use CDC ECM anyway
				# make sure ECM hasn't come up, too
				sleep 0.5
				if [ -f /sys/class/net/usb1/carrier ] && [[ $(</sys/class/net/usb1/carrier) == 1 ]]; then
					echo "Link detected on usb1"; sleep 2
					active_interface="usb1"
					ifconfig usb0 down

					break
				fi

				echo "Link detected on usb0"; sleep 2
				active_interface="usb0"
				ifconfig usb1 down

				break
			fi

			# check ECM for link
			if [ -f /sys/class/net/usb1/carrier ] && [[ $(</sys/class/net/usb1/carrier) == 1 ]]; then
				echo "Link detected on usb1"; sleep 2
				active_interface="usb1"
				ifconfig usb0 down

				break
			fi


			sleep 0.5
		done
	fi

	# if eiter one, RNDIS or ECM is active, wait for link on one of them
	if ($USE_RNDIS && ! $USE_ECM) || (! $USE_RNDIS && $USE_ECM); then 
		# bring up interface
		ifconfig usb0 up

		echo "CDC ECM or RNDIS active. Check which interface has to be used via Link detection"
		while [ "$active_interface" == "none" ]; do
			printf "."

			if [[ $(</sys/class/net/usb0/carrier) == 1 ]]; then
				echo "Link detected on usb0"; sleep 2
				active_interface="usb0"
				break
			fi
		done
	fi


	# setup active interface with correct IP
	if [ "$active_interface" != "none" ]; then
		ifconfig $active_interface $IF_IP netmask $IF_MASK
	fi

}
usb-ethernet-create-dhcp-config() {
	# create DHCP config file for dnsmasq
	echo "[ opsec ] Creating DHCP configuration for Ethernet over USB..."

	cat <<- EOF > /tmp/dnsmasq_usb_eth.conf
		bind-interfaces
		port=0
		interface=$active_interface
		listen-address=$IF_IP
		dhcp-range=$IF_DHCP_RANGE,$IF_MASK,5m

	EOF

	if $ROUTE_SPOOF; then
		cat <<- EOF >> /tmp/dnsmasq_usb_eth.conf
			# router
			dhcp-option=3,$IF_IP

			# DNS
			dhcp-option=6,$IF_IP

			# NETBIOS NS
			dhcp-option=44,$IF_IP
			dhcp-option=45,$IF_IP

			# routes static (route 0.0.0.1 to 127.255.255.254 through our device)
			dhcp-option=121,0.0.0.0/1,$IF_IP,128.0.0.0/1,$IF_IP
			# routes static (route 128.0.0.1 to 255.255.255.254 through our device)
			dhcp-option=249,0.0.0.0/1,$IF_IP,128.0.0.0/1,$IF_IP
		EOF
	else
		cat <<- EOF >> /tmp/dnsmasq_usb_eth.conf
			# router disable DHCP gateway announcment
			dhcp-option=3

			# disable DNS settings
			dhcp-option=6
		EOF
	fi

	if $WPAD_ENTRY; then
		cat <<- EOF >> /tmp/dnsmasq_usb_eth.conf
			dhcp-option=252,http://$IF_IP/wpad.dat
		EOF
	fi

	cat <<- EOF >> /tmp/dnsmasq_usb_eth.conf
		dhcp-leasefile=/tmp/dnsmasq.leases
		dhcp-authoritative
		log-dhcp
	EOF
}

# Bootstrap the script
run $@