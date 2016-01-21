#!/usr/bin/env ruby
require 'aws-sdk'
require 'json'
require 'trollop'

opts = Trollop::options do
  opt :all, "return all instances, not just those in-use", :short => 'a'
  opt :max, "return up to n instances. defaults to 1", :type => Integer
  opt :details, "display all instance details instead of just ip", :short => 'd'
  # opt :verbose, "display instance name as well as private ip address", :short => 'v'
  # opt :class, "class if other than pipeline", :short => 'c', :type => String
end

app_name = ARGV[0]
app_env  = ARGV[1]
app_class = opts[:class_given] ? opts[:class] : "pipeline"

if !(app_name && app_env)
  puts "ec2named wants app_name && app_env, in that order"
  exit
end

filters = []

if app_name == "jenkins"
  filters << {
    name: "tag:Name",
    values: ["#{app_env}-slave-#{app_name}"]
  }
else
  filters << {
    name: "tag:Name",
    values: ["*#{app_env}.#{app_class}.#{app_name}*"]
  }
end

ip_address = opts[:public] ? :public_ip_address : :private_ip_address


ec2_client = Aws::EC2::Client.new
response = ec2_client.describe_instances(filters: filters)

if opts[:details]
  output = response.reservations.map(&:instances).flatten.map do |instance|
    {
      instance_id: instance.instance_id,
      instance_type: instance.instance_type,
      name: instance.tags.find { |t| t.key == "Name" }.value
    }
  end
  puts output
else
  network_interfaces = response.reservations
    .map(&:instances).flatten
    .map(&:network_interfaces).flatten

  ips = network_interfaces
    .map(&:private_ip_addresses).flatten
    .map(&:private_ip_address)

  puts opts[:all] ? ips : ips.first(opts[:max] || 1)
end
