#!/bin/sh
# --------------------------------------------------------------------
# Service runtime configuration settings
# --------------------------------------------------------------------

# Variables are interpolated from template to config
# cat service.env.tpl | envsubst > service.env
APP_NAME=${APP_NAME:-"unknown"}
APP_HOME=${APP_HOME:-"$HOME/$APP_NAME"}