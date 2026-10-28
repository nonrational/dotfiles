alias ll 'ls -l'
alias la 'ls -hlA'
alias l ls
alias rm 'rm -v'
alias df 'df -h'
alias du 'du -h'
alias grep 'grep --color'
# fish lists history newest first; --reverse keeps bash's oldest-to-newest tail
alias hist 'history --reverse | tail'
alias psa 'ps auxwww'
# no inner quotes: fish's alias listing drops entries whose body needs quoting
alias cdate 'date +%Y%m%d%H%M%S'
