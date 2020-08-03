# set -x

autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats ' %b'

setopt PROMPT_SUBST
export PROMPT='%(?.%F{green}√.%F{red}?%?)%f %B%F{240}%1~%f%b%F{green}${vcs_info_msg_0_}%f %# '

export EDITNOW='vim'
export EDITOR='vim'
export CLICOLOR=1

alias ls='ls -F'
alias ll='ls -l'
alias l='ls'

host=$(uname -n | sed -e 's/\.local//g')

iamoscar() {
  echo "💪 Oscarian Strong!"
  source $HOME/.oscar_exports
  export PATH="/usr/local/opt/awscli@1/bin:$PATH"
  export ROLE=

  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
}

# TODO Modify prompt if AWS_* environment variables are set
aws_sre_creds(){
  eval $(TTL=240m LDAP_GROUP=engineering_techops_sre_staff $HOME/oscar/data/scripts/aws_creds)
  echo -n "🍄 until "
  gdate -d '+4 hour' --iso-8601=seconds | tee $HOME/.oscar_aws_creds_expires_at
}

brewery=$(brew --prefix)

# autojump
. "$brewery/etc/profile.d/autojump.sh"

# asdf
brew_prefix_asdf="$brewery/opt/asdf"
export ASDF_DIR="$brew_prefix_asdf"
source "$brew_prefix_asdf/asdf.sh"

# To make Homebrew’s completions available in zsh, you must get the Homebrew-managed zsh site-functions on your FPATH
# before initialising zsh’s completion facility.
# Add the following to your ~/.zshrc file:
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH

  autoload -Uz compinit
  compinit
fi

export PATH="/usr/local/opt/sqlite/bin:$PATH"

# https://gist.github.com/rubencaro/5ce32fb30bbfa70e7db6be14cf42a35c/2d804bb26e82cdcf9a43d7527e0cd74ae5ffd3c6
######## golang stuff

# # This goes up from current folder looking for a folder
# # that looks like a golang workspace root (has a 'src' subfolder, by now).
# # Then echoes its path and returns 0.
# # Returns -1 if does not find such a folder.
# function detect_go_workspace_root {
#   path="$PWD"
#   while [[ $path != / ]];
#   do
#     src="$path/src"
#     if [ -d "$src" ]; then
#       echo "$path" && return 0
#     fi
#     path="$(realpath -s "$path"/..)"  # ignoring symlinks
#   done
#   return -1
# }

# # This will setup the Go workspace to the detected root path.
# # It will complain if not detected.
# # Then it will cd into folder pointed by $GOPATH/.letsgo_srcpath
# function letsgo {
#   root=$(detect_go_workspace_root)
#   if [ $? -ne 0 ]; then
#     echo "Could not find Go Workspace Root for $PWD" && return -1
#   fi
#   export GOPATH=$root
#   export GOBIN=$root/bin
#   export PATH=$GOBIN:$PATH
#   export GOROOT=$(go env GOROOT)
#   srcpath="$root/.letsgo_srcpath"
#   [ -L "$srcpath" ] && cd "$(readlink $srcpath)"
# }

# # This will echo some funny symbol if we are inside current GOPATH.
# function ingopath {
#   [[ $PWD == "$(go env GOPATH)"* ]] && echo "(👀)"
# }

# ## then in the prompt
# export PS1='bla bla \[\033[00;36m\]$(ingopath)\[\033[00m\] bla bla $ '
