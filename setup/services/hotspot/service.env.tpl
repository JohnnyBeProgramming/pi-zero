#!/bin/sh
# --------------------------------------------------------------------
# Default setup config settings, if no payload overrides selected
# --------------------------------------------------------------------

# ===========================================
# Network and DHCP options USB over Ethernet
# ===========================================

# We choose an IP with a very small subnet (see comments in README.rst)
IF_IP="172.16.0.1" # IP used by P4wnP1
IF_MASK="255.255.255.252"
IF_DHCP_RANGE="172.16.0.2,172.16.0.2" # DHCP Server IP Range

# ============================
# WiFi options (only Pi Zero W)
# ============================
WIFI_REG=BE # WiFi regulatory domain (if not set accordingly, WiFi channels are missing)

# --------------------
# WiFi Client Settings
# --------------------
WIFI_CLIENT=false 	# enables connecting to existing WiFi (currently only WPA2 PSK)
WIFI_CLIENT_SSID="Accespoint Name" # name of target network
WIFI_CLIENT_PSK="AccessPoint password" # passphrase for target network


# ---------------------
# Access Point Settings
# ---------------------
WIFI_ACCESSPOINT=true
WIFI_ACCESSPOINT_NAME="club403.io"
WIFI_ACCESSPOINT_PSK="DangerDanger"
WIFI_ACCESSPOINT_AUTH=true # Use WPA2_PSK if true, no authentication if false
WIFI_ACCESSPOINT_CHANNEL=6

WIFI_ACCESSPOINT_IP="172.24.0.1" # IP used by P4wnP1
WIFI_ACCESSPOINT_NETMASK="255.255.255.0"
WIFI_ACCESSPOINT_DHCP_RANGE="172.24.0.2,172.24.0.100" # DHCP Server IP Range
WIFI_ACCESSPOINT_HIDE_SSID=false # use to hide SSID of WLAN (you have to manually connect to the name given by WIFI_ACCESSPOINT_NAME)

WIFI_ACCESSPOINT_DHCP_BE_GATEWAY=false # propagate P4wnP1 as router if true (only makes sense when an upstream is available
WIFI_ACCESSPOINT_DHCP_BE_DNS=false # propagate P4wnP1 as nameserver if true (only makes sense when an upstream is available
WIFI_ACCESSPOINT_DNS_FORWARD=false # if true, P4wnP1 listens with a DNS forwader on UPD port 53 of the WiFi interface (traffic is forwaded to P4wnP1's system DNS)

WIFI_ACCESSPOINT_KARMA=false # enables Karma attack with modified nexmon firmware, requires WIFI_NEXMON=true
WIFI_ACCESSPOINT_KARMA_LOUD=false # if true beacons for SSIDs spotted in probe requests are broadcasted (maximum 20)

