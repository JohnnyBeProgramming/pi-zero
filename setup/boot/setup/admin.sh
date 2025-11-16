#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
: "${SETUP_LAST_USER:=`getent passwd 1000 | cut -d: -f1`}"
: "${SETUP_USER_NAME:="admin"}"
: "${SETUP_USER_PASS:=""}"

# Check if the script should run...
[ ! "$SETUP_LAST_USER" == "" ] || exit 0

# Change the password of the last user
if [ ! -z "${SETUP_USER_PASS:-}" ]; then
    echo "Setting new password..."
    echo "$SETUP_LAST_USER:$(echo $SETUP_USER_PASS | openssl passwd -6 -stdin)" | chpasswd -e
fi

# Change the username if its changed
if [ "$SETUP_LAST_USER" != "$SETUP_USER_NAME" ]; then
    echo "Changing username from '$SETUP_LAST_USER' to  '$SETUP_USER_NAME'..."

    usermod -l "$SETUP_USER_NAME" "$SETUP_LAST_USER"
    usermod -m -d "/home/$SETUP_USER_NAME" "$SETUP_USER_NAME"
    groupmod -n "$SETUP_USER_NAME" "$SETUP_LAST_USER"

    # Check if desktop user should be updated
    if grep -q "^autologin-user=" /etc/lightdm/lightdm.conf ; then
        sed /etc/lightdm/lightdm.conf -i -e "s/^autologin-user=.*/autologin-user=$SETUP_USER_NAME/"
    fi

    # Update the user used to login to the terminal
    if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
        sed /etc/systemd/system/getty@tty1.service.d/autologin.conf -i -e "s/$SETUP_LAST_USER/$SETUP_USER_NAME/"
    fi

    # Update the sudo list for this user
    if [ -f /etc/sudoers.d/010_pi-nopasswd ]; then
        sed -i "s/^$SETUP_LAST_USER /$SETUP_USER_NAME /" /etc/sudoers.d/010_pi-nopasswd
    fi
fi