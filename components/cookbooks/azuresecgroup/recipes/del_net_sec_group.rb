require File.expand_path('../../libraries/network_security_group.rb', __FILE__)
require File.expand_path('../../../azure_base/libraries/logger.rb', __FILE__)
require File.expand_path('../../../azure_base/libraries/utils.rb', __FILE__)
require File.expand_path('../../../azure/libraries/resource_group.rb', __FILE__)

# set the proxy if it exists as a cloud var
Utils.set_proxy(node['workorder']['payLoad']['OO_CLOUD_VARS'])

# get all necessary info from node
cloud_name = node['workorder']['cloud']['ciName']
compute_service = node['workorder']['services']['compute'][cloud_name]['ciAttributes']
cred_hash = {
    tenant_id: compute_service['tenant_id'],
    client_secret: compute_service['client_secret'],
    client_id: compute_service['client_id'],
    subscription_id: compute_service['subscription']
}
ns_path_parts = node['workorder']['rfcCi']['nsPath'].split('/')
org = ns_path_parts[1]
assembly = ns_path_parts[2]
environment = ns_path_parts[3]
platform_ci_id = node['workorder']['box']['ciId']
location = compute_service[:location]

network_security_group_name = node[:name]

# Get resource group name
resource_group_name = AzureResources::ResourceGroup.get_name(org, assembly, platform_ci_id, environment, location)

# Creating security rules objects
nsg = AzureNetwork::NetworkSecurityGroup.new(cred_hash)
nsg_result = nsg.delete_security_group(resource_group_name, network_security_group_name)

if nsg_result
  Chef::Log.info("The network security group #{network_security_group_name} has been deleted")
else
  raise 'Error deleting network security group'
end
