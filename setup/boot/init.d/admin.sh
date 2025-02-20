#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
: "${LAST_USER:=`getent passwd 1000 | cut -d: -f1`}"
: "${USER_NAME:="admin"}"
: "${USER_PASS:=""}"

# Check if the script should run...
[ ! "$LAST_USER" == "" ] || exit 0
[ ! "$USER_PASS" == "" ] || exit 0

# Change the password of the last user
echo "$LAST_USER:$USER_PASS" | chpasswd -e

# Change the username if its changed
if [ "$LAST_USER" != "$USER_NAME" ]; then
    usermod -l "$USER_NAME" "$LAST_USER"
    usermod -m -d "/home/$USER_NAME" "$USER_NAME"
    groupmod -n "$USER_NAME" "$LAST_USER"
    if grep -q "^autologin-user=" /etc/lightdm/lightdm.conf ; then
        sed /etc/lightdm/lightdm.conf -i -e "s/^autologin-user=.*/autologin-user=$USER_NAME/"
    fi
    if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
        sed /etc/systemd/system/getty@tty1.service.d/autologin.conf -i -e "s/$LAST_USER/$USER_NAME/"
    fi
    if [ -f /etc/sudoers.d/010_pi-nopasswd ]; then
        sed -i "s/^$LAST_USER /$USER_NAME /" /etc/sudoers.d/010_pi-nopasswd
    fi
fi