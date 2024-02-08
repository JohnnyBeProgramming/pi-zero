#!/usr/bin/env bash
# See also: https://medium.com/@andersonpem/utm-on-apples-m1-file-sharing-with-debian-11-xfce-c5a262e27188

# Install required virtualisation
sudo apt install spice-vdagent spice-webdavd

# Install missing network file sharing libs
sudo apt install samba gvfs-backends 