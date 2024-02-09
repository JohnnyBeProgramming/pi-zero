#!/bin/sh
# --------------------------------------------------------------------
# Declares function used in conjunction with HID mouse
# --------------------------------------------------------------------

# output mouse commands from MouseScript (see $OPSEC_DIR/MouseScripts/test.mouse for example Script)
function outmouse()
{
#	cat | python $OPSEC_DIR/duckencoder/duckencoder.py -l $lang -r | python $OPSEC_DIR/transhid.py > /dev/hidg0
	cat | python $OPSEC_DIR/hidtools/mouse/MouseScriptParser.py 
}

