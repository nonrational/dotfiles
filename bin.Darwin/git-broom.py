#!/usr/bin/env python3

import os
import re
import subprocess

subprocess.run('git fetch origin --prune --tags -f'.split(), stdout=subprocess.PIPE, text=True)

remote_branches_ps = subprocess.run(['git branch --remote | grep "origin" | grep -v "HEAD" | cut -c10- | egrep -v "^master$\|^main$"'], shell=True, stdout=subprocess.PIPE, text=True)
local_branches_ps = subprocess.run(['git branch | grep -v "HEAD" | cut -c3- | egrep -v "^master$\|^main$"'], shell=True, stdout=subprocess.PIPE, text=True)

local_branches = local_branches_ps.stdout.split('\n')
remote_branches = remote_branches_ps.stdout.split('\n')

for local_branch in local_branches:
  if remote_branches.count(local_branch) == 0:
    response = input(f"Delete {local_branch}? (y/n): ")

    if re.match(r'^y', response, re.IGNORECASE):
      print(subprocess.run(['git', 'branch', '-D', local_branch], stdout=subprocess.PIPE, text=True).stdout)
