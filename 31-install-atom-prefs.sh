#!/usr/bin/env bash
git clone https://github.com/nonrational/atom $HOME/.atom

cd $HOME/.atom && ./script/apm-restore
