# autojump ships its fish integration (j, jc, jo, jco and the PWD hook that
# records visits) beside the binary rather than in fish's vendor_conf.d, so
# find it from the binary: share/autojump sits next to bin/ under both
# Homebrew and distro packages. Bash shares the same jump database.
status is-interactive; and command -q autojump; or return

set -l aj (path resolve (path dirname (command -s autojump))/../share/autojump/autojump.fish)
test -r $aj; and source $aj
