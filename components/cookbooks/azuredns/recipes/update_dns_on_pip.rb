# Returns true if Application Gateway is enabled, else returns false
def application_gateway_enabled?(cloud_name)
  enabled = false
  if !node['workorder']['services']['lb'].nil? &&
     !node['workorder']['services']['lb'][cloud_name].nil?

    cloud_service = node['workorder']['services']['lb'][cloud_name]
    Chef::Log.info("FQDN:: Cloud service name: #{cloud_service[:ciClassName]}")

    # Checks if Application Gateway service is enabled
    if cloud_service[:ciClassName].split('.').last.downcase =~ /azuregateway/
      enabled = true
      Chef::Log.info("FQDN::add Application Gateway Enabled: #{enabled}")
    end
  end
  enabled
end

# Returns true if Express Route is enabled, else returns false
def express_route_enabled?(dns_attributes)
  enabled = dns_attributes['express_route_enabled']
  Chef::Log.info("express_route_enable is: #{enabled}")
  enabled == 'true'
end

def formate_zone_name(dns_attributes)
  zone_name = dns_attributes['zone']
  zone_name.split('.').reverse.join('.').partition('.').last
           .split('.').reverse.join('.').tr('.', '-')
end

# set the proxy if it exists as a cloud var
Utils.set_proxy(node['workorder']['payLoad']['OO_CLOUD_VARS'])

# get platform resource group and availability set
include_recipe 'azure::get_platform_rg_and_as'
OOLog.info("azuredns:update_dns_on_pip.rb - platform-resource-group is: #{node['platform-resource-group']}")

cloud_name = node['workorder']['cloud']['ciName']
dns_attributes = node['workorder']['services']['dns'][cloud_name]['ciAttributes']

# Exit from this recipe if both Express Route and Application Gateway are enabled
return 0 if express_route_enabled?(dns_attributes) && application_gateway_enabled?(cloud_name)

subscription = dns_attributes['subscription']
resource_group = node['platform-resource-group']
zone_name = formate_zone_name(dns_attributes)

credentials = {
    tenant_id: dns_attributes['tenant_id'],
    client_secret: dns_attributes['client_secret'],
    client_id: dns_attributes['client_id'],
    subscription_id: subscription
}

public_ip = AzureDns::PublicIp.new(resource_group, credentials, zone_name)

domain_name_label = public_ip.update_dns(node)
node.set['domain_name_label'] = domain_name_label unless domain_name_label.nil?
