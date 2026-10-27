# Interactive-only setup lives here so scripts and `fish -c` stay fast and quiet.
if status is-interactive
end

# Last: this runs after every conf.d file, so no later fish_add_path call can
# push ./bin out of first place. Set directly because fish_add_path resolves
# relative paths to absolute ones, which would lose the per-directory ./bin.
set -gx PATH ./bin $PATH
