#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
: "${SETUP_LOCALE_TIMEZONE:=""}"
: "${SETUP_KEYBOARD_LAYOUT:=""}"
: "${SETUP_KEYBOARD_MODEL:=""}"

# Set Timezone (if specified)
if [ ! -z "${SETUP_LOCALE_TIMEZONE:-}" ]; then
    echo "Setting Timezone: $SETUP_LOCALE_TIMEZONE"
    rm -f /etc/localtime
    echo "$SETUP_LOCALE_TIMEZONE" >/etc/timezone
    dpkg-reconfigure -f noninteractive tzdata
fi

# Change keyboard layout (if specified)
if [ ! "${SETUP_KEYBOARD_LAYOUT:-}" == "" ] && [ ! "${SETUP_KEYBOARD_MODEL:-}" == "" ]; then
    echo "Set Keyboard layout: $SETUP_KEYBOARD_LAYOUT ($SETUP_KEYBOARD_MODEL)"
    cat >/etc/default/keyboard << KBEOF
XKBMODEL="$LOCALE_SETUP_KEYBOARD_MODEL"
XKBLAYOUT="$LOCALE_SETUP_KEYBOARD_LAYOUT"
XKBVARIANT=""
XKBOPTIONS=""
KBEOF
    dpkg-reconfigure -f noninteractive keyboard-configuration
fi