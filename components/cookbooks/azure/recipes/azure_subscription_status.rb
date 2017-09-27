require 'json'
require 'fog/azurerm'
require File.expand_path('../../../azure_base/libraries/logger.rb', __FILE__)

# Set the proxy if apiproxy exists as a system var.
env_vars = node['workorder']['ci']['ciAttributes']['env_vars']
env_vars_hash = JSON.parse(env_vars)
Chef::Log.info("APIPROXY is: #{env_vars_hash['apiproxy']}")
unless env_vars_hash['apiproxy'].nil?
  ENV['http_proxy'] = env_vars_hash['apiproxy']
  ENV['https_proxy'] = env_vars_hash['apiproxy']
end

subscription_details = node[:workorder][:ci][:ciAttributes]

cred_hash = {
  tenant_id: subscription_details[:tenant_id],
  client_id: subscription_details[:client_id],
  client_secret: subscription_details[:client_secret],
  subscription_id: subscription_details[:subscription]
}

resource_group_name = subscription_details[:resource_group]
express_route_enabled = subscription_details['express_route_enabled']
OOLog.info("tenant_id: #{cred_hash[:tenant_id]} client_id: #{cred_hash[:client_id]} client_secret: #{cred_hash[:client_secret]} subscription: #{cred_hash[:subscription_id]}")
client = Fog::Resources::AzureRM.new(cred_hash)

if express_route_enabled == 'true'
  begin
    # First, check if resource group is already created
    response = client.resource_groups.check_resource_group_exists(resource_group_name)
    OOLog.info('response from azure:' + response.inspect)
    if response
      OOLog.info('Subscription details entered are verified')
    else
      OOLog.fatal("Error verifying the subscription and credentials for #{cred_hash[:subscription_id]}")
    end
  rescue MsRestAzure::AzureOperationError => e
    Chef::Log.error("Error verifying the subscription and credentials for #{cred_hash[:subscription_id]}")
    node.set['status_result'] = 'Error'
    if !e.body.nil?
      error_response = e.body['error']
      Chef::Log.error('Error Response code:' + error_response['code'] + '\n\rError Response message:' + error_response['message'])
      OOLog.fatal(error_response['message'])
    else
      Chef::Log.error('Error:' + e.inspect)
      OOLog.fatal("Error verifying the subscription and credentials for #{cred_hash[:subscription_id]}")
    end
  end
elsif express_route_enabled == 'false' || express_route_enabled == nil
  begin
    # First, get list if resources associated with subscription just to verify subscription and credentials
    response = client.resource_groups
    OOLog.debug('response from azure:' + response.inspect)
    if !response.nil?
      OOLog.info('Subscription details entered are verified')
    else
      OOLog.fatal("Error verifying the subscription and credentials for #{cred_hash[:subscription_id]}")
    end
  rescue MsRestAzure::AzureOperationError => e
    Chef::Log.error("Error verifying the subscription and credentials for #{cred_hash[:subscription_id]}")
    node.set['status_result'] = 'Error'
    if !e.body.nil?
      error_response = e.body['error']
      Chef::Log.error('Error Response code:' + error_response['code'] + '\n\rError Response message:' + error_response['message'])
      OOLog.fatal(error_response['message'])
    else
      Chef::Log.error('Error:' + e.inspect)
      OOLog.fatal("Error verifying the subscription and credentials for #{cred_hash[:subscription_id]}")
    end
  end
end
