#!/usr/bin/env bash

if [ -e /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg ]; then
  echo 'Installing Mojave Development Headers'
  sudo installer -pkg /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg -target /
fi

sudo touch /var/db/ntp-kod
sudo chmod 666 /var/db/ntp-kod
