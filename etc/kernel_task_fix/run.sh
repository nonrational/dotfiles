#!/bin/bash

sudo unzip AppleHDA.10.8.5.kext.zip

sudo mv /System/Library/Extensions/AppleHDA.kext /System/Library/Extensions/AppleHDA.10.9.kext
sudo mv ./AppleHDA.10.8.5.kext /System/Library/Extensions/AppleHDA.10.8.5.kext
sudo chown -R root:wheel /System/Library/Extensions/AppleHDA.10.8.5.kext

sudo ln -s /System/Library/Extensions/AppleHDA.10.8.5.kext /System/Library/Extensions/AppleHDA.kext

sudo touch  /System/Library/Extensions
