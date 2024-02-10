#!/bin/sh
# --------------------------------------------------------------
# This script starts a system service rasberry pi device
# --------------------------------------------------------------

main() {
    if [ ! -d "$APP_HOME" ]
    then
        # Pull the application sources from git
        git clone $APP_REPO $APP_HOME
    fi
    
    # Create systemd service for startup and persistence
    # Note: switched to multi-user.target to make nexmon monitor mode work
    if [ ! -f /etc/systemd/system/$APP_NAME.service ]; then
        echo "Injecting 'opsec' startup script..."
        cat <<- EOF | sudo tee /etc/systemd/system/$APP_NAME.service > /dev/null
[Unit]
Description=OpSec Startup Service
#After=systemd-modules-load.service
After=local-fs.target
DefaultDependencies=no
Before=sysinit.target

[Service]
#Type=oneshot
Type=forking
RemainAfterExit=yes
ExecStart=/bin/bash $APP_HOME/boot/boot_simple
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
#WantedBy=sysinit.target
EOF
    fi
    
    sudo systemctl enable $APP_NAME.service
}

# Bootstrap the script
main $@