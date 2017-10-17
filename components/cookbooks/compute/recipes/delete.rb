#
# Cookbook Name:: compute
# Recipe:: delete
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

include_recipe "compute::node_lookup"
include_recipe "shared::set_provider_new"

Chef::Log.info("compute::delete -- name: #{node[:server_name]}")

if node[:provider_class] =~ /vagrant|virtualbox|docker|lxd/
  include_recipe "compute::del_node_#{node[:provider_class]}"
elsif node[:provider_class] =~ /azure/
  include_recipe 'azure::del_node'
elsif node[:provider_class] =~ /vsphere/
  include_recipe 'vsphere::del_node'
else
  include_recipe "compute::del_node_fog"
end
