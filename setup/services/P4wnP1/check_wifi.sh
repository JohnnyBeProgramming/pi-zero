#/bin/bash
# --------------------------------------------------------------------
# Check for presence of wlan0
# --------------------------------------------------------------------
if ! iwconfig 2>&1 | grep -q -E ".*wlan0.*"; then
        echo "...[Error] no wlan0 interface found"
        exit 1
fi
exit 0