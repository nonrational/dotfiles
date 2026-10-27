# Same precedence as .bash_profile, where each entry was prepended in turn so
# the last one listed there wins. --path keeps this in the session; without it
# fish_add_path writes the universal fish_user_paths, which persists in
# fish_variables and would override this file as the source of truth.
# fish_add_path skips directories that do not exist, so one list serves every host.
fish_add_path --move --path $HOME/.docker/bin $HOME/bin $HOME/.local/bin $HOME/.asdf/shims /opt/homebrew/sbin /opt/homebrew/bin

# Interactive-only setup lives here so scripts and `fish -c` stay fast and quiet.
if status is-interactive
end

# Last, so it ends up first. Set directly because fish_add_path resolves
# relative paths to absolute ones, which would lose the per-directory ./bin.
set -gx PATH ./bin $PATH
