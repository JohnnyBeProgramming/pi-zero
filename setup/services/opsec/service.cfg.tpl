[Unit]
Description=$SETUP_NAME - Startup Service
#After=systemd-modules-load.service
After=local-fs.target
DefaultDependencies=no
Before=sysinit.target

[Service]
#Type=oneshot
Type=forking
RemainAfterExit=yes
ExecStart=/bin/bash $APP_HOME/service.sh
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
#WantedBy=sysinit.target