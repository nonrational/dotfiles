# PATH setup lives in conf.d because fish loads conf.d before config.fish,
# so later conf.d files such as starship.fish need the full PATH already set.

# Same precedence as .bash_profile, where each entry was prepended in turn so
# the last one listed there wins. --path keeps this in the session; without it
# fish_add_path writes the universal fish_user_paths, which persists in
# fish_variables and would override this file as the source of truth.
# fish_add_path skips directories that do not exist, so one list serves every host.
fish_add_path --move --path $HOME/.docker/bin $HOME/bin $HOME/.local/bin $HOME/.asdf/shims /opt/homebrew/sbin /opt/homebrew/bin
