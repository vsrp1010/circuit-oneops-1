require 'fog'

include_recipe "shared::set_provider_new"
  
instance_id = node.workorder.ci[:ciAttributes][:instance_id]
server = node.iaas_provider.servers.get instance_id

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
 