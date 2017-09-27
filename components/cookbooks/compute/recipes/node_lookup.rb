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

rfcCi = node["workorder"]["rfcCi"]
nsPathParts = rfcCi["nsPath"].split("/")
server_name = node[:workorder][:box][:ciName]+'-'+nsPathParts[3]+'-'+nsPathParts[2]+'-'+nsPathParts[1]+'-'+ rfcCi["ciId"].to_s

if(server_name.size > 63)
  server_name = server_name.slice(0,63-(rfcCi["ciId"].to_s.size)-1)+'-'+ rfcCi["ciId"].to_s
  Chef::Log.info("Truncated server name to 64 chars : #{server_name}")
end

cloud_name = node[:workorder][:cloud][:ciName]
cloud = node[:workorder][:services][:compute][cloud_name][:ciAttributes]

os = nil
ostype = "default-cloud"
if node[:workorder][:payLoad].has_key?("os")
  os = node[:workorder][:payLoad][:os].first
  ostype = os[:ciAttributes][:ostype]
else
  Chef::Log.warn("missing os payload - using default-cloud")
  if ostype == "default-cloud"
    ostype = cloud[:ostype]
  end
end

sizemap = JSON.parse( cloud[:sizemap] )
imagemap = JSON.parse( cloud[:imagemap] )

# size / flavor
size_id = sizemap[rfcCi["ciAttributes"]["size"]]
Chef::Log.debug("node_lookup SizeID: #{size_id}")
# image_id
image_id = ''
if !os.nil? && os[:ciAttributes].has_key?("image_id") && !os[:ciAttributes][:image_id].empty?
  image_id = os[:ciAttributes][:image_id]
else
  image_id = imagemap[ostype]
end
Chef::Log.debug("node_lookup imageID: #{image_id}")
if rfcCi["rfcAction"] != "delete" && (image_id.nil? || image_id.empty?)
  exit_with_error "Compute image id provided is null or empty. Please specify different OS type."
end

kp_name = ""
if node[:workorder][:payLoad].has_key?("SecuredBy")
  env_ci_id = node[:workorder][:payLoad][:Environment][0][:ciId].to_s
  env_ci_name = node[:workorder][:payLoad][:Environment][0][:ciName]
  kp_name = "oneops_key."+ env_ci_id +'.'+ env_ci_name + "." + node[:workorder][:box][:ciId].to_s
else
  Chef::Log.error("missing SecuredBy payload")
  exit 1
end

# hostname
platform_name = node[:workorder][:box][:ciName]
if(platform_name.size > 32)
  platform_name = platform_name.slice(0,32) #truncate to 32 chars
  Chef::Log.info("Truncated platform name to 32 chars : #{platform_name}")
end

# initial user for installing ruby, chef, and nagios
initial_user = "root"
if ostype.include?("buntu") &&
    # rackspace uses root for all images
    !node[:workorder][:cloud][:ciAttributes][:location].include?("rackspace") &&
    !node[:workorder][:cloud][:ciName].downcase.include?("rackspace")

   initial_user = "ubuntu"
end

# ibm uses idcuser
if node[:workorder][:cloud][:ciName].include?("ibm.")
  initial_user = "idcuser"
end

if ostype.include?("edora") || ostype.include?("mazon")
  initial_user = "ec2-user"
end

# override via inductor.properties
if node.has_key?("initial_user") && node[:initial_user] != "unset"
  Chef::Log.info("initial user: "+node[:initial_user])
  initial_user = node[:initial_user]
end

node.set[:initial_user] = initial_user
node.set[:vmhostname] = platform_name+'-'+node[:workorder][:cloud][:ciId].to_s+'-'+
                        node["workorder"]["rfcCi"]["ciName"].split('-').last.to_i.to_s+'-'+
                        node["workorder"]["rfcCi"]["ciId"].to_s
node.set[:server_name] = server_name
node.set[:ostype] = ostype
node.set[:size_id] = size_id
node.set[:image_id] = image_id
node.set[:kp_name] = kp_name
node.set[:repo_list] = os['ciAttributes']['repo_list']
