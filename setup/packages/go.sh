#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------

# Install golang
#sudo apt-get install golang

# Install newer version of golang
local tag="1.21.4"
local arch=$(uname -m)
if ! go version | grep $tag > /dev/null; then
    wget https://go.dev/dl/go$tag.linux-$arch.tar.gz
    sudo tar -C /usr/local -xzf go$tag.linux-$arch.tar.gz
    rm go$tag.linux-$arch.tar.gz
fi

if ! cat ~/.profile | grep GOPATH > /dev/null; then
    cat << EOF >> ~/.profile
GOPATH="\$HOME/go"
PATH="\$GOPATH/bin:/usr/local/go/bin:\$PATH"
EOF
fi
source ~/.profile