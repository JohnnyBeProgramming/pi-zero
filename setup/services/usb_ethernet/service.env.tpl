#!/bin/sh
# --------------------------------------------------------------------
# Default setup config settings, if no payload overrides selected
# --------------------------------------------------------------------

# ---------------------------
# USB setup
# ---------------------------
# Make sure to change USB_PID if you enable different USB functionality in order
# to force Windows to enumerate the device again
USB_VID="0x1d6b"        # Vendor ID
USB_PID="0x0137"        # Product ID
USE_ECM=false           # if true CDC ECM will be enabled
USE_RNDIS=false         # if true RNDIS will be enabled
USE_HID=false           # if true HID (keyboard) will be enabled
USE_HID_MOUSE=false     # if true HID mouse will be enabled
USE_RAWHID=false        # if true a raw HID device will be enabled
USE_UMS=false           # if true USB Mass Storage will be enabled

# ===========================================
# Network and DHCP options USB over Ethernet
# ===========================================

# We choose an IP with a very small subnet (see comments in README.rst)
IF_IP="172.16.0.1" # IP used by P4wnP1
IF_MASK="255.255.255.252"
IF_DHCP_RANGE="172.16.0.2,172.16.0.2" # DHCP Server IP Range

