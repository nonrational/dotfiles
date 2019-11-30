#!/usr/bin/env bash

git clone https://github.com/nonrational/sublime3 $HOME/.sublime3 || echo 'got it'
rm -rf $HOME/Library/Application\ Support/Sublime\ Text\ 3
ln -s $HOME/.sublime3 $HOME/Library/Application\ Support/Sublime\ Text\ 3
