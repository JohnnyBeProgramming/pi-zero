#!/usr/bin/env bash

sudo iwlist scan | grep "ESSID:" | cut -d ':' -f2-