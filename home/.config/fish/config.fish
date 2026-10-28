# Interactive-only setup lives here so scripts and `fish -c` stay fast and quiet.
if status is-interactive
  set -g fish_greeting
  command -q op; and op completion fish | source
end

# Before the ./bin line so ./bin stays first, as in bash where .bash_profile
# prepends it after .bashrc has sourced the local file.
test -r ~/.local/config.fish; and source ~/.local/config.fish

# Last: this runs after every conf.d file, so no later fish_add_path call can
# push ./bin out of first place. Set directly because fish_add_path resolves
# relative paths to absolute ones, which would lose the per-directory ./bin.
set -gx PATH ./bin $PATH
