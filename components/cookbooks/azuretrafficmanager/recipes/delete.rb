require File.expand_path('../../libraries/traffic_managers.rb', __FILE__)

# set the proxy if it exists as a cloud var
Utils.set_proxy(node.workorder.payLoad.OO_CLOUD_VARS)

nsPathParts = node['workorder']['rfcCi']['nsPath'].split('/')
cloud_name = node['workorder']['cloud']['ciName']
dns_attributes = node['workorder']['services']['dns'][cloud_name]['ciAttributes']
credentials = {
    tenant_id: dns_attributes['tenant_id'],
    client_secret: dns_attributes['client_secret'],
    client_id: dns_attributes['client_id'],
    subscription_id: dns_attributes['subscription']
}
include_recipe 'azure::get_platform_rg_and_as'
resource_group_name = node['platform-resource-group']
resource_group_names = []
resource_group_names.push(resource_group_name)
platform_name = nsPathParts[5]
profile_name = 'trafficmanager-' + platform_name
begin
  traffic_manager_processor = TrafficManagers.new(resource_group_name, profile_name, credentials)
  traffic_manager_processor.delete_profile
  Chef::Log.info('Exiting Traffic Manager Deleted successfully')
rescue => e
  OOLog.fatal("Error deleting Traffic Manager Profile: #{e.message}")
end
