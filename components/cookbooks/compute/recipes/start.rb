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
  
instance_id = node[:workorder][:ci][:ciAttributes][:instance_id]
server = node[:iaas_provider].servers.get instance_id

if server == nil
  Chef::Log.error("cannot find server by name: "+server_name)
  return false
end

Chef::Log.info("server: "+server.inspect.gsub(/\n|\<|\>|\{|\}/,""))

server.start
Chef::Log.info("start in progress")
sleep 10

server.wait_for { ready? } 
Chef::Log.info("server ready")
 