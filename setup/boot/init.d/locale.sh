#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
: "${LOCALE_TZ:=""}"
: "${KEYBOARD_LAYOUT:=""}"
: "${KEYBOARD_MODEL:=""}"

# Set Timezone (if specified)
if [ ! -z "${LOCALE_TZ:-}" ]; then
    rm -f /etc/localtime
    echo "$LOCALE_TZ" >/etc/timezone
    dpkg-reconfigure -f noninteractive tzdata
fi

# Change keyboard layout (if specified)
if [ ! "${KEYBOARD_LAYOUT:-}" == "" ] && [ ! "${KEYBOARD_MODEL:-}" == "" ]; then
    # Set Keyboard layout
    cat >/etc/default/keyboard <<'KBEOF'
XKBMODEL="$LOCALE_KEYBOARD_MODEL"
XKBLAYOUT="$LOCALE_KEYBOARD_LAYOUT"
XKBVARIANT=""
XKBOPTIONS=""

KBEOF
    dpkg-reconfigure -f noninteractive keyboard-configuration
fi