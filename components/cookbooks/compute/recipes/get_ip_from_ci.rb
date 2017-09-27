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

ci = node[:workorder][:ci] || node[:workorder][:rfcCi]

if node.has_key?("ip")
  Chef::Log.info("using ip: #{node[:ip]}")
  return
end

ci = node[:workorder][:ci] || node[:workorder][:rfcCi]

cloud_name = node[:workorder][:cloud][:ciName]
provider = node[:workorder][:services][:compute][cloud_name][:ciClassName].downcase
Chef::Log.info("provider :" + provider)
Chef::Log.info("node :" + node.inspect)

ip = nil
if provider =~ /openstack|azure/
  ip = ci[:ciAttributes][:private_ip] || ci[:ciAttributes][:public_ip]
else
  ip = ci[:ciAttributes][:public_ip]
end
# once inductor ActionOrderExecutor is released with change to populate node[:ip_attribute] we can move to:
# node.set[:ip] = ci[:ciAttributes][node[:ip_attribute]]

node.set[:ip] = ip
