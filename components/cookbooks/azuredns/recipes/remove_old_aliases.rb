require File.expand_path('../../libraries/record_set.rb', __FILE__)
require File.expand_path('../../libraries/dns.rb', __FILE__)
require File.expand_path('../../../azure_base/libraries/logger.rb', __FILE__)
require File.expand_path('../../../azure_base/libraries/utils.rb', __FILE__)

::Chef::Recipe.send(:include, AzureDns)

#set the proxy if it exists as a cloud var
Utils.set_proxy(node.workorder.payLoad.OO_CLOUD_VARS)

# get platform resource group and availability set
include_recipe 'azure::get_platform_rg_and_as'

# get the azure token for making rest api calls to azure
include_recipe 'azuredns::get_azure_token'

cloud_name = node['workorder']['cloud']['ciName']
zone_name =
    node['workorder']['services']['dns'][cloud_name]['ciAttributes']['zone']

cloud_service = node['workorder']['services']['dns'][cloud_name]
service_attrs = cloud_service['ciAttributes']

dns = AzureDns::DNS.new(node['platform-resource-group'], node['azure_rest_token'], service_attrs)

# ex) customer_domain: env.asm.org.oneops.com
customer_domain = dns.normalize_customer_domain(node.customer_domain)

customer_domain = dns.remove_zone_name_from_customer_domain(customer_domain, zone_name)
OOLog.info("azuredns:remove_old_aliases.rb
            - NEW customer_domain is: #{customer_domain}")


# Checking if the platform is active
# if active then skip
box = node['workorder']['box']['ciAttributes']
if box.key?(:is_active) && box[:is_active] == 'false'
  OOLog.info('azuredns:remove_old_aliases.rb - skipping due to platform is_active false')
  return
end

# checking id cloud dns id is nil, if nil, throw an exception
dns.check_cloud_dns_id(service_attrs, cloud_service)


is_hostname_entry = dns.entrypoint_exists(node.workorder.payLoad)
hash_of_removed_aliases = dns.remove_all_aliases(node.workorder.rfcCi, is_hostname_entry)
if !hash_of_removed_aliases.empty?
  aliases = []
  full_aliases = []
  hash_of_removed_aliases.each do |entry|
    name = entry[:name]
    if name == "aliases"
      aliases = entry[:values]
    end
    if name == "full_aliases"
      full_aliases = entry[:values]
    end
  end
  priority = node.workorder.cloud.ciAttributes.priority
  dns.remove_old_aliases(customer_domain, priority, service_attrs['cloud_dns_id'], aliases, full_aliases)
end
