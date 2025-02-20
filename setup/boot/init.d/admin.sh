FIRSTUSER=`getent passwd 1000 | cut -d: -f1`
USER_PASS='' # openssl passwd -6 -salt xyz  yourpass

echo "$FIRSTUSER:$USER_PASS" | chpasswd -e

if [ "$FIRSTUSER" != "admin" ]; then
    usermod -l "admin" "$FIRSTUSER"
    usermod -m -d "/home/admin" "admin"
    groupmod -n "admin" "$FIRSTUSER"
    if grep -q "^autologin-user=" /etc/lightdm/lightdm.conf ; then
        sed /etc/lightdm/lightdm.conf -i -e "s/^autologin-user=.*/autologin-user=admin/"
    fi
    if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
        sed /etc/systemd/system/getty@tty1.service.d/autologin.conf -i -e "s/$FIRSTUSER/admin/"
    fi
    if [ -f /etc/sudoers.d/010_pi-nopasswd ]; then
        sed -i "s/^$FIRSTUSER /admin /" /etc/sudoers.d/010_pi-nopasswd
    fi
fi