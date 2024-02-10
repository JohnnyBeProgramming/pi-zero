#!/usr/bin/env bash

# Install NodeJS
if ! which npm > /dev/null; then
    sudo apt install -y nodejs npm
    sudo npm install --global yarn
fi

# Upgrade node to latest stable version
sudo npm cache clean -f
sudo npm install -g n
sudo n stable