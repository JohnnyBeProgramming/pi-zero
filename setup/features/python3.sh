#!/usr/bin/env bash

# Install Python v3
sudo apt-get -y install python3-pip python3-dev

upgrade-python-latest() {
    local tag="3.11.5"
    local bin="python3.11"

    if [ ! -f /usr/local/bin/$bin ]
    then
        wget https://www.python.org/ftp/python/$tag/Python-$tag.tgz
        tar -zxvf Python-$tag.tgz
        cd Python-$tag
        ./configure --enable-optimizations
        sudo make altinstall
        cd ..
        rm -rf Python-$tag
        rm -f Python-$tag.tgz

        pushd /usr/bin > /dev/null
        sudo rm python
        sudo ln -s /usr/local/bin/$bin python
        popd /dev/null
    fi
}

# Try and install the specified version
upgrade-python-latest ""