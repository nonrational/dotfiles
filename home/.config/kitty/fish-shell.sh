#!/bin/bash
# Included by kitty.conf through `geninclude`: print the `shell` line only when
# fish is installed, so a Mac without fish keeps kitty's default shell instead
# of opening windows that fail to start. FISH_BIN overrides the path for tests.
fish="${FISH_BIN:-/opt/homebrew/bin/fish}"
# --login because fish reads /etc/paths and /etc/paths.d only in a login shell,
# and kitty started from the Dock hands it launchd's bare /usr/bin:/bin PATH.
if [ -x "$fish" ]; then
  echo "shell $fish --login --interactive"
fi
exit 0
