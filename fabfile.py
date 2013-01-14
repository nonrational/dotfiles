# pavement.py

from fabric.api import task, roles, with_settings, run, cd, local, lcd, env, sudo, settings, prompt, abort
from fabric.contrib.files import exists
from fabric.contrib.console import confirm
from fabric.context_managers import hide
import os.path
import datetime
import re
import hashlib

env.dotfiles = 'git@github.com:nonrational/dotfiles.git'
env.ignore = ['.DS_Store','.git','.gitignore']

@task
@with_settings(hide('warnings', 'running', 'stderr'), warn_only=True)
def push():
    name = local('uname -n', capture=True).replace(".local","")
    kind = local('uname', capture=True)
    print "{0} is {1}".format(name, kind)

    flist = os.listdir(".")
    for fname in flist:
        print fname

