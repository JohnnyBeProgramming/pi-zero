#!/bin/sh
# --------------------------------------------------------------------
# Simple debug script to check service status
# --------------------------------------------------------------------
ACTION=${1:-""}
APP_NAME=${APP_NAME:-"opsec"}

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
