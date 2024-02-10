#!/usr/bin/env bash

install-opsec-tools() {
    # nmap:         Nmap ("Network Mapper") is an open source tool for network exploration and security auditing.
    # dirbuster:    DirBuster is a multi threaded java application designed to brute force directories and files names on web/application servers.
    # gobuster:     Discover directories and files that match in the wordlist (written on golang)
    sudo apt install -y nmap gobuster #dirbuster
    
    # Install hugo (static site generator)
    #sudo apt install -y hugo
    CGO_ENABLED=1 \
    go install -tags extended github.com/gohugoio/hugo@latest
    
    # Install taskfile as a golang package
    go install github.com/go-task/task/v3/cmd/task@latest
    
}

install-opsec-tools