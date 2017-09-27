require File.expand_path('../../libraries/traffic_managers.rb', __FILE__)
require File.expand_path('../../libraries/model/traffic_manager.rb', __FILE__)
require File.expand_path('../../libraries/model/dns_config.rb', __FILE__)
require File.expand_path('../../libraries/model/monitor_config.rb', __FILE__)
require File.expand_path('../../libraries/model/endpoint.rb', __FILE__)
require File.expand_path('../../../azure_lb/libraries/load_balancer.rb', __FILE__)
require File.expand_path('../../../azure/libraries/public_ip.rb', __FILE__)
require File.expand_path('../../../azure_base/libraries/utils.rb', __FILE__)
require 'chef'

def get_resource_group_names
  ns_path_parts = node['workorder']['rfcCi']['nsPath'].split('/')
  org = ns_path_parts[1]
  assembly = ns_path_parts[2]
  environment = ns_path_parts[3]

  resource_group_names = []
  remotegdns_list = node['workorder']['payLoad']['remotegdns']
  remotegdns_list.each do |remotegdns|
    location = remotegdns['ciAttributes']['location']
    resource_group_name = org[0..15] + '-' + assembly[0..15] + '-' + node.workorder.box.ciId.to_s + '-' + environment[0..15] + '-' + Utils.abbreviate_location(location)
    resource_group_names.push(resource_group_name)
  end
  Chef::Log.info('remotegdns resource groups: ' + resource_group_names.to_s)
  resource_group_names
end

def get_traffic_manager_resource_group(resource_group_names, profile_name, credentials)
  resource_group_names.each do |resource_group_name|
    traffic_manager_processor = TrafficManagers.new(resource_group_name, profile_name, credentials)
    Chef::Log.info('Checking traffic manager FQDN set in resource group: ' + resource_group_name)
    profile = traffic_manager_processor.get_profile
    return resource_group_name unless profile.nil?
  end
  nil
end

# set the proxy if it exists as a cloud var
Utils.set_proxy(node.workorder.payLoad.OO_CLOUD_VARS)

ns_path_parts = node['workorder']['rfcCi']['nsPath'].split('/')
cloud_name = node['workorder']['cloud']['ciName']
dns_attributes = node['workorder']['services']['dns'][cloud_name]['ciAttributes']
gdns_attributes = node['workorder']['services']['gdns'][cloud_name]['ciAttributes']
listeners = node['workorder']['payLoad']['lb'][0][:ciAttributes][:listeners]
subdomain = node['workorder']['payLoad']['Environment'][0]['ciAttributes']['subdomain']

credentials = {
    tenant_id: dns_attributes['tenant_id'],
    client_secret: dns_attributes['client_secret'],
    client_id: dns_attributes['client_id'],
    subscription_id: dns_attributes['subscription']
}

begin
  resource_group_names = get_resource_group_names
  profile_name = 'trafficmanager-' + ns_path_parts[5]
  resource_group_name = get_traffic_manager_resource_group(resource_group_names, profile_name, credentials)

  traffic_manager_processor = TrafficManagers.new(resource_group_name, profile_name, credentials)
  traffic_manager = traffic_manager_processor.initialize_traffic_manager(dns_attributes, resource_group_names, ns_path_parts, gdns_attributes, listeners, subdomain)
  node.set[:entries] = traffic_manager_processor.entries

  if resource_group_name.nil?
    include_recipe 'azure::get_platform_rg_and_as'
    resource_group_name = node['platform-resource-group']
    traffic_manager_processor = TrafficManagers.new(resource_group_name, profile_name, credentials)
    traffic_manager_profile_result = traffic_manager_processor.create_update_profile(traffic_manager)
    if traffic_manager_profile_result.nil?
      OOLog.fatal("Traffic Manager profile #{profile_name} could not be created")
    end
  else
    traffic_manager_processor = TrafficManagers.new(resource_group_name, profile_name, credentials)
    profile_deleted = traffic_manager_processor.delete_profile
    if profile_deleted
      traffic_manager_profile_result = traffic_manager_processor.create_update_profile(traffic_manager)
      if traffic_manager_profile_result.nil?
        OOLog.fatal("ERROR recreating Traffic Manager profile #{profile_name}")
      end
    else
      Chef::Log.error('Failed to delete traffic manager.')
      exit 1
    end
  end
  Chef::Log.info('Traffic Manager created successfully')
rescue => e
  OOLog.fatal("Error creating Traffic Manager: #{e.message}")
end
