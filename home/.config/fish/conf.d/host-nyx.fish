# Same host id as scripts/host-id.sh, so the bash and fish host files agree.
set -l host (string replace -r '\.(lan|local)$' '' (uname -n))
test "$host" = nyx; or return

# Use the 1Password ssh agent.
set -gx SSH_AUTH_SOCK "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# 1Password CLI plugin wrappers, ported by hand from ~/.config/op/plugins.sh
# because fish cannot source a bash file. `op plugin init` regenerates that
# bash file, so a newly initialised plugin needs its alias added here too.
set -gx OP_PLUGIN_ALIASES_SOURCED 1
alias aws "op plugin run -- aws"

# --path keeps this in the session; see 00-path.fish.
fish_add_path --move --path $HOME/.cargo/bin /opt/homebrew/opt/postgresql@18/bin
