# Installing pi hole

 - See also: https://www.tomshardware.com/how-to/static-ip-raspberry-pi

 - Make sure you have a fresh new image on a SD card, and enable some features:
   The image mounted for me at `/Volumes/bootfs`.
```bash
# File: /Volumes/bootfs/cmdline.txt
# Append: net.ifnames=0
BOOT_FILE="/Volumes/bootfs/cmdline.txt"
BOOT_ARGS=("net.ifnames=0")
for feat in $BOOT_ARGS; do grep "$feat" $BOOT_FILE || cat $BOOT_FILE | sed "s|\$| $feat|" | tee $BOOT_FILE; done
```
 - Now you can unmount the disk, insert SD card into pi and boot the pi up...

 - Connect to the pi over Wifi or network cable
```
ssh admin@pihole.local << EOF

# Get current IP address
hostname -I

# Get the router IP address
ip r

# Get the DNS name server
grep "nameserver" /etc/resolv.conf

EOF
```

 - Next we need to set a static IP for our pi. Use the info collected above. 
```
sudo nano /etc/dhcpcd.conf

# File: /etc/dhcpcd.conf
interface [INTERFACE]
static ip_address=[STATIC IP ADDRESS YOU WANT]/24
static_routers=[ROUTER IP]
static domain_name_servers=[DNS IP]

# Example command (see CIDR range here: https://cidr.xyz/)
ssh admin@pihole.local 'sudo /bin/bash -c "cat /dev/stdin > /etc/dhcpcd.conf" && reboot' << EOF

interface wlan0
static ip_address=192.168.128.99/24
static_routers=192.168.128.1
static domain_name_servers=192.168.128.1

EOF

# Or reserve a IP address
ssh admin@pihole.local 'sudo /bin/bash -c "cat /dev/stdin > /etc/dhcpcd.conf" && sudo reboot' << EOF

interface wlan0
request 192.168.128.99

EOF
```

 - Take note of the static IP that we set, and restart the pi for the static IP to take effect
```
sudo reboot

# Wait for restart

ssh admin@192.168.128.255
```

 - Install the pi-hole from install script 
```
curl -sSL https://install.pi-hole.net | bash
```