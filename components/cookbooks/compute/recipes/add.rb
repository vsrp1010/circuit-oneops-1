#
# Cookbook Name:: compute
# Recipe:: add
#
# Copyright 2016, Walmart Stores, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

start_time = Time.now.to_i
include_recipe "compute::node_lookup"

Chef::Log.info("compute::add -- name: #{node[:server_name]}")
puts "***RESULT:instance_name=#{node[:server_name]}"

Chef::Log.info("ostype: #{node[:ostype]} size: #{node[:size_id]} image: #{node[:image_id]}")

cloud_name = node[:workorder][:cloud][:ciName]
provider = node[:workorder][:services][:compute][cloud_name][:ciClassName].gsub("cloud.service.","").downcase.split(".").last
node.set['cloud_provider'] = provider
Chef::Log.info("Cloud Provider: #{provider}")

# refactoring azure specific recipe to an azure folder to make it easier to manage all the files.
if provider =~ /azure/
  include_recipe 'azure::add_node'
elsif provider =~ /vsphere/
  include_recipe 'vsphere::add_node'
else
  include_recipe "compute::add_node_"+provider
end

ruby_block "duration" do
  block do
    duration = Time.now.to_i - start_time
    Chef::Log.info("took #{duration} sec to create or update ssh port open")
  end
end

# clear ptr on replace
if node[:workorder][:rfcCi].has_key?(:ciState) && node[:workorder][:rfcCi][:ciState] == "replace"
  cloud_name = node[:workorder][:cloud][:ciName]
  provider_service = node[:workorder][:services][:dns][cloud_name][:ciClassName].split(".").last.downcase
  provider = "fog"
  case provider_service
  when /infoblox/
    provider = "infoblox"
  when /azuredns/
    provider = "azuredns"
  when /designate/
    provider = "designate"
  end
  include_recipe "fqdn::remove_ptr_"+provider
end

# sleeps based on average time for ssh to be ready even tho port is up
sleep_time = 10
if provider == "ec2"
  case node[:ostype]
  when /centos|redhat/
    sleep_time = 30
  end
elsif provider == "docker"
  sleep_time = 1
end

Chef::Log.info("Action is: #{node[:workorder][:rfcCi][:rfcAction]}")

ruby_block "wait for boot" do
  block do
    Chef::Log.info("waiting #{sleep_time}sec based on avg ready time for cloud provider and ostype")
    sleep sleep_time
  end
end

include_recipe "compute::base"
