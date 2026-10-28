# Guarded so a host with fish but no starship keeps fish's default prompt
# and prints nothing at startup.
status is-interactive; and command -q starship; or return

starship init fish | source
