# NONE

# TODO: Figure out why this makes VSCode happy.
if [ -f "$HOME/.asdf/asdf.sh" ]; then
  echo "Sourcing asdf.sh via .profile"
  source $HOME/.asdf/asdf.sh
fi
