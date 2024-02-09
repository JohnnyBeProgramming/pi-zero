#!/bin/sh
# --------------------------------------------------------------------
# Simple debug script to check service status
# --------------------------------------------------------------------
APP_NAME="opsec"
APP_HOME="$HOME/app"


case $1 in
    all) 
		# List all system services
		systemctl --type=service
	;;
    logs) 
		# Show the service logs
		journalctl -b		
	;;
    start|stop|restart) 
		# Start, stop or restart the service
		sudo systemctl $1 $APP_NAME.service
	;;
	*) 
		# Default: Show the service logs
		journalctl -u "$APP_NAME.service"
	;;
esac
