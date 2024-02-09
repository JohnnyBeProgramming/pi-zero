#!/usr/bin/env bash

# Install rust and cargo
if ! which cargo > /dev/null; then
    curl https://sh.rustup.rs -sSf | bash -s -- -y
fi