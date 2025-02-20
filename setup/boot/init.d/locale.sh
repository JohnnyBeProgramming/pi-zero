LOCALE_TZ="Europe/Brussels"
LOCALE_KEYBOARD_LAYOUT="us"
LOCALE_KEYBOARD_MODEL="pc105"

# Set Timezone
rm -f /etc/localtime
echo "$LOCALE_TZ" >/etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# Set Keyboard layout
cat >/etc/default/keyboard <<'KBEOF'
XKBMODEL="$LOCALE_KEYBOARD_MODEL"
XKBLAYOUT="$LOCALE_KEYBOARD_LAYOUT"
XKBVARIANT=""
XKBOPTIONS=""

KBEOF
dpkg-reconfigure -f noninteractive keyboard-configuration