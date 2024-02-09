#!/bin/sh
# --------------------------------------------------------------------
# Start LED controller script and provide funtion to set blink count
# --------------------------------------------------------------------
THIS_DIR=$(cd $(dirname $BASH_SOURCE[0]) && pwd)

# create control file and change owner (otherwise it would be created by ledtool.py
# with owner root, and thus not writable by user)
ledtrigger="/tmp/blink_count"
echo 255 > $ledtrigger
chmod 0666 $ledtrigger
sync

# start LED control in background
python $THIS_DIR/ledtool.py&

# led blink function
function led_blink()
{
	if [ "$1" ] 
	then
		echo "$1" > $ledtrigger
	fi
}

# disable LED for now
led_blink 0
