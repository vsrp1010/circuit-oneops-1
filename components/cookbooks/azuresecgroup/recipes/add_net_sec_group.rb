require File.expand_path('../../libraries/network_security_group.rb', __FILE__)
require File.expand_path('../../../azure_base/libraries/logger.rb', __FILE__)
require File.expand_path('../../../azure_base/libraries/utils.rb', __FILE__)
require File.expand_path('../../../azure/libraries/resource_group.rb', __FILE__)

# set the proxy if it exists as a cloud var
Utils.set_proxy(node['workorder']['payLoad']['OO_CLOUD_VARS'])

# get all necessary info from node
cloud_name = node['workorder']['cloud']['ciName']
compute_service = node['workorder']['services']['compute'][cloud_name]['ciAttributes']
credentials = {
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
nsg = AzureNetwork::NetworkSecurityGroup.new(credentials)
rules = node['secgroup']['inbound'].tr('"[]\\', '').split(',')
sec_rules = []
priority = 100
reg_ex = /(\d+|\*|\d+-\d+)\s(\d+|\*|\d+-\d+)\s([A-Za-z]+|\*)\s\S+/
rules.each do |item|
  raise "#{item} is not a valid security rule" unless reg_ex.match(item)
  item2 = item.split(' ')
  security_rule_access = Fog::ARM::Network::Models::SecurityRuleAccess::Allow
  security_rule_description = node['secgroup']['description']
  security_rule_source_addres_prefix = item2[3]
  security_rule_destination_port_range = item2[1].to_s
  security_rule_direction = Fog::ARM::Network::Models::SecurityRuleDirection::Inbound
  security_rule_priority = priority
  security_rule_protocol = case item2[2].downcase
                           when 'tcp'
                             Fog::ARM::Network::Models::SecurityRuleProtocol::Tcp
                           when 'udp'
                             Fog::ARM::Network::Models::SecurityRuleProtocol::Udp
                           else
                             Fog::ARM::Network::Models::SecurityRuleProtocol::Asterisk
                           end
  security_rule_provisioning_state = nil
  security_rule_destination_addres_prefix = '*'
  security_rule_source_port_range = '*'
  security_rule_name = network_security_group_name + '-' + priority.to_s
  sec_rules << { name: security_rule_name, resource_group: resource_group_name, protocol: security_rule_protocol, network_security_group_name: network_security_group_name, source_port_range: security_rule_source_port_range, destination_port_range: security_rule_destination_port_range, source_address_prefix: security_rule_source_addres_prefix, destination_address_prefix: security_rule_destination_addres_prefix, access: security_rule_access, priority: security_rule_priority, direction: security_rule_direction }
  priority += 100
end

parameters = Fog::Network::AzureRM::NetworkSecurityGroup.new
parameters.location = location
parameters.security_rules = sec_rules

nsg_result = nsg.create_update(resource_group_name, network_security_group_name, parameters)

if !nsg_result.nil?
  Chef::Log.info("The network security group has been created\n\rid: '#{nsg_result.id}'\n\r'#{nsg_result.location}'\n\r'#{nsg_result.name}'\n\r")
else
  raise 'Error creating network security group'
end
