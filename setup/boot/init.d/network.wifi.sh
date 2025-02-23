#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
: "${WIFI_COUNTRY:=""}"
: "${WIFI_SSID:=""}"
: "${WIFI_PSK:=""}"
: "${WIFI_INTERFACE:="DIR=/var/run/wpa_supplicant GROUP=netdev"}"

# Check if th script should run
[ ! "${WIFI_COUNTRY:-}" == "" ] || exit 0
[ ! "${WIFI_SSID:-}" == "" ] || exit 0
[ ! "${WIFI_PSK:-}" == "" ] || exit 0

echo "Configuring wifi settings:"
echo " - Country: $WIFI_COUNTRY"
echo " - SSID: $WIFI_SSID"


# Create the wifi configuration (if provided)
cat >/etc/wpa_supplicant/wpa_supplicant.conf <<'WPAEOF'
country=$WIFI_COUNTRY
ctrl_interface=$WIFI_INTERFACE
ap_scan=1

update_config=1
network={
	ssid="$WIFI_SSID"
	psk=$WIFI_PSK
}
WPAEOF

# Apply wifi settings
chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
rfkill unblock wifi
for filename in /var/lib/systemd/rfkill/*:wlan ; do
    echo 0 > $filename
done