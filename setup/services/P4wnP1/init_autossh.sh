#!/bin/bash
# --------------------------------------------------------------------
# Enable AutoSSH reachback connection according to the settings of 
# setup.env or current payload
# --------------------------------------------------------------------

function start_autossh()
{
	if $AUTOSSH_ENABLED; then
		echo "Forwarding P4wnP1 SSH server to \"$AUTOSSH_REMOTE_HOST\" ..."
		echo "    P4wnP1 SSH will be reachable on localhost:$AUTOSSH_REMOTE_PORT on this server"
		cp $AUTOSSH_PRIVATE_KEY /tmp/ssh_id

		sudo autossh -M 0 -f -T -N  -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -i /tmp/ssh_id -R localhost:$AUTOSSH_REMOTE_PORT:localhost:22 $AUTOSSH_REMOTE_USER@$AUTOSSH_REMOTE_HOST
	fi
}
