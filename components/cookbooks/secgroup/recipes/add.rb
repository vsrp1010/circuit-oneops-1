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

#
# Cookbook Name:: Secgroup
# Recipe:: add
#

include_recipe "secgroup::setup"

case node[:provider_class]
when /azure/
    include_recipe "azuresecgroup::add_net_sec_group"
    
when /ec2|openstack|aliyun/
  include_recipe "secgroup::add_secgroup_"+node[:provider_class]

  # need to always return the attrs, updated or not
  puts "***RESULTJSON:group_id="+JSON.generate({"value" => node[:secgroup][:group_id]})
  puts "***RESULTJSON:group_name="+JSON.generate({"value" => node[:secgroup][:group_name]})

else

  Chef::Log.info("secgroup add not implemented for provider")
  puts "***RESULT:group_id=NA"
  puts "***RESULT:group_name=NA"

end
