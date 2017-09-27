# Cookbook Name:: keypair
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

include_recipe "keypair::setup"

case node[:provider_class]
when /vagrant|lxd|aliyun/
  Chef::Log.info("keypair add not implemented for provider")
when /azure/
    include_recipe "azurekeypair::add"
    if node[:workorder][:rfcCi][:rfcAction] == "update" || node[:workorder][:rfcCi][:rfcAction] == "replace"
      include_recipe "keypair::update_authorized_keys"
    end
when /vsphere/
  Chef::Log.info("keypair add not implemented for provider")
else
  include_recipe "keypair::add_keypair_"+node[:provider_class]
  include_recipe "keypair::update_authorized_keys"
end

ruby_block 'setup security groups' do
  block do
    puts "***RESULTJSON:private="+JSON.generate({"value" => node['keypair']['private']})
    puts "***RESULTJSON:public="+JSON.generate({"value" => node['keypair']['public']})
    puts "***RESULT:key_name=#{node['kp_name']}"
  end
end
