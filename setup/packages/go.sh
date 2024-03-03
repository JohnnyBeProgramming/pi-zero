#!/usr/bin/env bash
# --------------------------------------------------------------
set -euo pipefail # Stop running the script on first error...
# --------------------------------------------------------------
arch=$(uname -m)
tag="go1.21.4"

# Load the go path (if not already set)
[ ! -f ~/.profile ] || source ~/.profile

if which go > /dev/null; then
    local_version=$(go version | cut -d ' ' -f3)
    if [[ "${local_version:-}" < "$tag" ]]; then
        echo "Go version out of date, upgrading (from ${local_version:-})..."
    else
        exit 0 # Up to date
    fi
fi

# Install golang (official way is sligntly outdated)
#sudo apt-get install golang

# Install newer version of golang
wget https://go.dev/dl/$tag.linux-$arch.tar.gz
sudo tar -C /usr/local -xzf $tag.linux-$arch.tar.gz
rm $tag.linux-$arch.tar.gz

if ! cat ~/.profile | grep GOPATH > /dev/null; then
    cat << EOF >> ~/.profile
GOPATH="\$HOME/go"
PATH="\$GOPATH/bin:/usr/local/go/bin:\$PATH"
EOF
fi
source ~/.profile