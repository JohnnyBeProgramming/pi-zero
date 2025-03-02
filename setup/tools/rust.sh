#!/usr/bin/env bash

[ ! -f $HOME/.cargo/env ] || source $HOME/.cargo/env

# Install rust and cargo
if ! which cargo > /dev/null; then
    curl https://sh.rustup.rs -sSf | bash -s -- -y
fi