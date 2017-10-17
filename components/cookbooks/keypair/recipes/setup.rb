require 'openssl'

include_recipe "shared::set_provider_new"

puts "env_ci_id: #{node[:workorder][:payLoad].inspect}"

env_ci_id = node[:workorder][:payLoad][:Environment][0][:ciId].to_s
env_ci_name = node[:workorder][:payLoad][:Environment][0][:ciName]

if node[:workorder][:rfcCi][:ciAttributes].has_key?("key_name") && !node[:workorder][:rfcCi][:ciAttributes][:key_name].empty?
   node.set["kp_name"] = node[:workorder][:rfcCi][:ciAttributes][:key_name]
else
   node.set["kp_name"] = 'oneops_key.' + env_ci_id + '.' + env_ci_name + '.' + node[:workorder][:box][:ciId].to_s
end

if node[:workorder][:rfcCi].has_key?("rfcAction")
   if node[:workorder][:rfcCi][:rfcAction].downcase == 'add'
      node.set["key_name"] = 'oo.' + env_ci_id + '.' + env_ci_name + '.' + node[:workorder][:box][:ciId].to_s + '-' + node[:workorder][:rfcCi][:ciId].to_s
   end
end

if !node[:keypair].has_key?("private") ||
   node[:keypair][:private] == 'keygen'
   
  Chef::Log.info("generating ssh keys")
  
  tuuid = "/tmp/" + (0..32).to_a.map{|a| rand(32).to_s(32)}.join
  cmd = "ssh-keygen -t rsa -b 2048 -N \"\" -f #{tuuid}"
  out = `#{cmd}`
  if $?.to_i != 0
    Chef::Log.error("had issue running #{cmd}")
    exit 1
  end
  cmd = "ssh-keygen -y -f #{tuuid} > #{tuuid}.pub"
  out = `#{cmd}`
  if $?.to_i != 0
    Chef::Log.error("had issue running #{cmd}")
    exit 1
  end  
  private_key = `cat #{tuuid}`  
  public_key = `cat #{tuuid}.pub`
  `rm -f #{tuuid}*`
  
  kp = {}
  kp[:private] = private_key
  kp[:public] = public_key
  node.set["keypair"] = kp

end