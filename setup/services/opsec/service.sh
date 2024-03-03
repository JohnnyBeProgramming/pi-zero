#!/bin/sh
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
# This script starts a system service rasberry pi device
# --------------------------------------------------------------
THIS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

config() {
    
    # Load the basic config (if present)
    if [ -f $THIS_DIR/service.env ]
    then
        echo "[ opsec ] Loading config: $THIS_DIR/service.env"
        source $THIS_DIR/service.env
    else
        echo "[ opsec ] Warning: No config found at $THIS_DIR/service.env"
    fi    
}

run() {
	echo "========================= OpSec tools starting up ======================"
    config $@ # Load config settings
	
	# Initialise all the modules
	echo "Start task server..."
	task --version
	cat

	echo "========================================================================="
}

# Bootstrap the script
run $@