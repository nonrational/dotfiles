function reset_known_host --argument-names pattern
  if test -z "$pattern"
    echo "No pattern provided"
    return
  end
  grep -v -- "$pattern" $HOME/.ssh/known_hosts > $HOME/.ssh/known_hosts.tmp
  mv -v $HOME/.ssh/known_hosts.tmp $HOME/.ssh/known_hosts
end
