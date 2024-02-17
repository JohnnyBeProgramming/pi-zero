#!/bin/sh
# --------------------------------------------------------------------
# Declares function used in conjunction with HID keyboard
# --------------------------------------------------------------------

# output raw ASCII to HID keyboard
function outhid()
{
#	cat | python $OPSEC_DIR/duckencoder/duckencoder.py -l $lang -r | python $OPSEC_DIR/transhid.py > /dev/hidg0
	cat | python $OPSEC_DIR/duckencoder/duckencoder.py -l $lang -r | python $OPSEC_DIR/hidtools/transhid.py 
}

# output DUCKY SCRIPT to HID keyboard
function duckhid()
{
#	cat | python $OPSEC_DIR/duckencoder/duckencoder.py -l $lang -p | python $OPSEC_DIR/transhid.py > /dev/hidg0
	cat | python $OPSEC_DIR/duckencoder/duckencoder.py -l $lang -p | python $OPSEC_DIR/hidtools/transhid.py 
}

# Blocks till NUMLOCK, CAPSLOCK or SCROLLLOCK has been hit 5 time on targets keyboard
# return value define which key was hit
function key_trigger()
{
	sudo python $OPSEC_DIR/hidtools/watchhidled.py trigger
	return $?
}

# reads LEDs from keyboard device till something is sent
# as this is done on driver init, we use it as trigger for HID keyboard beeing ready

#function detect_HID_keyboard()
#{
#	echo "Waiting for HID keyboard to be usable..."
#
#	# blocking read of LED status
#	python -c "with open('/dev/hidg0','rb') as f:  print ord(f.read(1))"
#	# fire 'onKeyboardUp' after read has succeeded
#	declare -f onKeyboardUp > /dev/null && onKeyboardUp
#
#}
