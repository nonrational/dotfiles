#!/usr/bin/env ruby

`git fetch origin --prune --tags -f`

remote_branches = `git branch --remote | grep "origin" | grep -v "HEAD" | cut -c10- | egrep -v "^master$\|^main$"`.split("\n")
local_branches = `git branch | grep -v "HEAD" | cut -c3- | egrep -v "^master$\|^main$"`.split("\n")

local_branches.each do |lb|
  unless remote_branches.include? lb
    print "Delete #{lb}? (y/n): "
    puts `git branch -D #{lb}` if /\Ay/i =~ gets.chomp
  end
end
