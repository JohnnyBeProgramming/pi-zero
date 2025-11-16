#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
: "${SETUP_LOCALE_COUNTRY:=""}"
: "${SETUP_NETWORK_WIFI_SSID:=""}"
: "${SETUP_NETWORK_WIFI_PSK:=""}"
: "${WIFI_INTERFACE:="DIR=/var/run/wpa_supplicant GROUP=netdev"}"

# Check if th script should run
[ ! "${SETUP_LOCALE_COUNTRY:-}" == "" ] || exit 0
[ ! "${SETUP_NETWORK_WIFI_SSID:-}" == "" ] || exit 0
[ ! "${SETUP_NETWORK_WIFI_PSK:-}" == "" ] || exit 0

echo "Configuring wifi settings:"
echo " - Country: $SETUP_LOCALE_COUNTRY"
echo " - SSID: $SETUP_NETWORK_WIFI_SSID"

# Create the wifi configuration (if provided)
cat << WPAEOF > /etc/wpa_supplicant/wpa_supplicant.conf
country=$SETUP_LOCALE_COUNTRY
ctrl_interface=$WIFI_INTERFACE
ap_scan=1

update_config=1
network={
	ssid="$SETUP_NETWORK_WIFI_SSID"
	psk=$SETUP_NETWORK_WIFI_PSK
}
WPAEOF

# Apply wifi settings
chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
rfkill unblock wifi
for filename in /var/lib/systemd/rfkill/*:wlan ; do
    echo 0 > $filename
done