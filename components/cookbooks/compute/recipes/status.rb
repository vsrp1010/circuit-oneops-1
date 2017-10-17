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

require 'fog'

include_recipe "shared::set_provider_new"

ci = node[:workorder][:ci]
Chef::Log.debug("ci attrs:"+ci[:ciAttributes].inspect.gsub("\n"," "))  
instance_id = ci[:ciAttributes][:instance_id]

cloud_name = node[:workorder][:cloud][:ciName]
provider = node[:workorder][:services][:compute][cloud_name][:ciClassName].gsub("cloud.service.","").downcase

if provider =~ /azure/
	include_recipe "azure::status_node"
	if node['status_result'] == "Error"
		 return false
	end
else
  server = node[:iaas_provider].servers.get instance_id
  
  if server == nil
    Chef::Log.error("cannot find server by instance_id: "+instance_id)
    return false
  end
  
  Chef::Log.info("server: "+server.inspect.gsub(/\n|\<|\>|\{|\}/,""))
end
