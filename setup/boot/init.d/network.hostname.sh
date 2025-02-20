CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
DESIRED_HOSTNAME=""

echo "$DESIRED_HOSTNAME" > /etc/hostname
sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$DESIRED_HOSTNAME/g" /etc/hosts
