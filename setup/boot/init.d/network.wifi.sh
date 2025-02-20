WIFI_SSID=${WIFI_SSID:-"$(exit 0)"}
WIFI_PSK=${WIFI_PSK:-"$(exit 0)"}
WIFI_COUNTRY="BE"
WIFI_INTERFACE="DIR=/var/run/wpa_supplicant GROUP=netdev"

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


chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
rfkill unblock wifi
for filename in /var/lib/systemd/rfkill/*:wlan ; do
    echo 0 > $filename
done