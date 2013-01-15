Why?
---- 
Because storing cross-machine config is cumbersome. Installing Git is &mdash; for the most part &mdash; easy.

Making it Work
--------
Getting Started:

    git clone https://github.com/nonrational/dotfiles ~/.dotfiles && cd !$
    ./pu.sh
    
Alternatively (requires wget but not git):

    mkdir ~/dotfiles && cd !$
    wget https://github.com/nonrational/dotfiles/archive/master.zip && unzip master.zip
    ./pu.sh
    
Arguments to pu.sh:
* -f : Delete all files WITHOUT ASKING YOU before symlinking in the new ones.
* -r : Apply root@host rules. Don't do this on shared systems unless you can beat up everyone else in `finger`

Notes
-------
If you find a smarter way to do something, [let me know](mailto:me@alannorton.com)! 
