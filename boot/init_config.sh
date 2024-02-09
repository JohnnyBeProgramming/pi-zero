#!/bin/sh
# --------------------------------------------------------------------
# Load global configuration variables defined in setup.env
# --------------------------------------------------------------------
THIS_DIR=$(cd $(dirname $0) && pwd)

# include setup.env
if [ -f $OPSEC_DIR/setup.env ]
then
    source $OPSEC_DIR/setup.env
fi

# include payload (overrides variables set by setup.env if needed)
if [ ! -z "$PAYLOAD" ] && [ -f $OPSEC_DIR/payloads/$PAYLOAD ]
then
    # PAYLOAD itself is define in setup.env
    source $OPSEC_DIR/payloads/$PAYLOAD
fi

# check for wifi capability
if $THIS_DIR/check_wifi.sh; then WIFI=true; else WIFI=false; fi

# set variable for USB gadget directory
#GADGETS_DIR="usb_gadget"

