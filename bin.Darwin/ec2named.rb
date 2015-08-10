#!/usr/bin/ruby
require 'json'
# require 'thor'

app_name = ARGV[0]
app_env  = ARGV[1]
app_class = ARGV[2] || "pipeline"

if !(app_name && app_env)
  puts "ec2named wants app_name && app_env, in that order"
  exit
end

di = JSON.parse(`aws ec2 describe-instances --filters "Name=tag:Name,Values=*#{app_env}.#{app_class}.#{app_name}*"`)

puts di["Reservations"]
  .map{ |r| r["Instances"]
    .map { |n| n["NetworkInterfaces"]
      .map { |nic| nic["PrivateIpAddresses"][0]["PrivateIpAddress"] }
    }
  }
