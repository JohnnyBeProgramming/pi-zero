#!/usr/bin/env bash

pushd /tmp > /dev/null

git clone https://github.com/RustScan/RustScan.git
cd ./RustScan && cargo build --release
mv ./target/release/rustscan /usr/local/bin/rustscan

popd > /dev/null