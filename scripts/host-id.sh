# Shared OS/host derivation, sourced by deploy.sh, the shell rc files, and
# the test suite so the same `uname` transform can't drift between them again
# -- home/.zshrc's own copy already had (it only stripped .local, not .lan).

os_id() {
    uname
}

host_id() {
    uname -n | sed -e 's/\.lan$//g' -e 's/\.local$//g'
}
