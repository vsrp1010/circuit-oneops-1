require File.expand_path('../../libraries/application_gateway.rb', __FILE__)
require File.expand_path('../../../azure/libraries/public_ip.rb', __FILE__)
require File.expand_path('../../../azure/libraries/virtual_network.rb', __FILE__)

require 'azure_mgmt_network'
require 'rest-client'
require 'chef'
require 'json'
require 'base64'

::Chef::Recipe.send(:include, Utils)
::Chef::Recipe.send(:include, AzureNetwork)
::Chef::Recipe.send(:include, Azure::ARM::Network)
::Chef::Recipe.send(:include, Azure::ARM::Network::Models)

# get platform resource group and availability set
include_recipe 'azure::get_platform_rg_and_as'

include_recipe 'azuredns::get_azure_token'
token = node['azure_rest_token']

def get_compute_nodes
  compute_nodes = []
  compute_list = node.workorder.payLoad.DependsOn.select { |d| d[:ciClassName] =~ /Compute/ }
  if compute_list
    # Build compute nodes to load balance
    compute_list.each do |compute|
      compute_nodes.push(compute[:ciAttributes][:private_ip])
    end
  end
  compute_nodes
end

def create_public_ip(creds, location, resource_group_name)
  public_ip = AzureNetwork::PublicIp.new(creds)
  public_ip.location = location
  public_ip_address = public_ip.build_public_ip_object(node['workorder']['rfcCi']['ciId'], 'ag_publicip')
  public_ip.create_update(resource_group_name, public_ip_address.name, public_ip_address)
end

def get_vnet(resource_group_name, vnet_name, virtual_network)
  virtual_network.name = vnet_name
  vnet = virtual_network.get(resource_group_name)

  if vnet.nil?
    OOLog.fatal("Could not retrieve vnet '#{vnet_name}' from express route")
  end
  vnet
end

def get_ag_service(cloud_name)
  if !node.workorder.services['lb'].nil? && !node.workorder.services['lb'][cloud_name].nil?
    ag_service = node.workorder.services['lb'][cloud_name]
    return ag_service
  end

  OOLog.fatal('missing application gateway service') if ag_service.nil?
end

def get_compute_service(cloud_name)
  if !node.workorder.services['compute'].nil? && !node.workorder.services['compute'][cloud_name].nil?
    compute_service = node.workorder.services['compute'][cloud_name]
    return compute_service
  end

  OOLog.fatal('missing compute service') if compute_service.nil?
end

def express_route_enabled?(ag_service)
  express_route_enabled = true
  if ag_service[:ciAttributes][:express_route_enabled].nil? || ag_service[:ciAttributes][:express_route_enabled] == 'false'
    express_route_enabled = false
  end
  express_route_enabled
end

def cookie_enabled?(ag_service)
  enable_cookie = true
  if ag_service[:ciAttributes][:cookies_enabled].nil? || ag_service[:ciAttributes][:cookies_enabled] == 'false'
    enable_cookie = false
  end
  enable_cookie
end

cloud_name = node.workorder.cloud.ciName
ag_service = get_ag_service(cloud_name)

compute_service = get_compute_service(cloud_name)

platform_name = node.workorder.box.ciName
environment_name = node.workorder.payLoad.Environment[0]['ciName']
assembly_name = node.workorder.payLoad.Assembly[0]['ciName']
org_name = node.workorder.payLoad.Organization[0]['ciName']
security_group = "#{environment_name}.#{assembly_name}.#{org_name}"
resource_group_name = node['platform-resource-group']
subscription_id = ag_service[:ciAttributes]['subscription']
location = ag_service[:ciAttributes][:location]

asmb_name = assembly_name.gsub(/-/, '').downcase
plat_name = platform_name.gsub(/-/, '').downcase
env_name = environment_name.gsub(/-/, '').downcase
ag_name = "ag-#{plat_name}"
creds = {
    tenant_id: ag_service[:ciAttributes][:tenant_id],
    client_secret: ag_service[:ciAttributes][:client_secret],
    client_id: ag_service[:ciAttributes][:client_id],
    subscription_id: subscription_id
}
tenant_id = ag_service[:ciAttributes][:tenant_id]
client_id = ag_service[:ciAttributes][:client_id]
client_secret = ag_service[:ciAttributes][:client_secret]

network_address = compute_service[:ciAttributes][:network_address].strip

OOLog.info("Cloud Name: #{cloud_name}")
OOLog.info("Org: #{org_name}")
OOLog.info("Assembly: #{asmb_name}")
OOLog.info("Platform: #{platform_name}")
OOLog.info("Environment: #{env_name}")
OOLog.info("Location: #{location}")
OOLog.info("Security Group: #{security_group}")
OOLog.info("Resource Group: #{resource_group_name}")
OOLog.info("Application Gateway: #{ag_name}")

# ===== Create a Application Gateway =====
#   # AG Creation Steps
#
#   # 1 - Create public IP
#   # 2 - Create Gateway Ip Configurations
#   # 3 - Create backend address pool
#   # 4 - Create http settings
#   # 5 - Create FrontendIPConfig
#   # 6 - Create SSL Certificate
#   # 7 - Listener
#   # 8 - Routing rule, SKU
#   # 9 - Create Application Gateway

begin
  credentials = Utils.get_credentials(tenant_id, client_id, client_secret)
  application_gateway = AzureNetwork::Gateway.new(resource_group_name, ag_name, creds)

  # Determine if express route is enabled
  express_route_enabled = express_route_enabled?(ag_service)

  token = credentials.instance_variable_get(:@token_provider)

  virtual_network = AzureNetwork::VirtualNetwork.new(creds)
  public_ip = nil
  if express_route_enabled
    vnet_name = ag_service[:ciAttributes][:network]
    master_rg = ag_service[:ciAttributes][:resource_group]
    vnet = get_vnet(master_rg, vnet_name, virtual_network)

    if vnet.subnets.count < 1
      OOLog.fatal("VNET '#{vnet_name}' does not have subnets")
    end
  else
    # Create public IP
    public_ip = create_public_ip(creds, location, resource_group_name)
    vnet_name = 'vnet_' + network_address.gsub('.', '_').gsub('/', '_')
    vnet = get_vnet(resource_group_name, vnet_name, virtual_network)
  end

  gateway_subnet_address = ag_service[:ciAttributes][:gateway_subnet_address]
  gateway_subnet_name = 'GatewaySubnet'

  # Add a subnet for Gateway
  vnet = virtual_network.add_gateway_subnet_to_vnet(vnet, gateway_subnet_address, gateway_subnet_name)
  rg_name = master_rg.nil? ? resource_group_name : master_rg
  vnet = virtual_network.create_update(rg_name, vnet)
  gateway_subnet = nil
  vnet.subnets.each do |subnet|
    if subnet.name == gateway_subnet_name
      gateway_subnet = subnet
      break
    end
  end

  # Application Gateway configuration
  application_gateway.set_gateway_configuration(gateway_subnet)

  # Backend Address Pool
  backend_ip_address_list = get_compute_nodes
  application_gateway.set_backend_address_pool(backend_ip_address_list)

  # Gateway Settings
  data = ''
  password = ''
  ssl_certificate_exist = false
  certs = node.workorder.payLoad.DependsOn.select { |d| d[:ciClassName] =~ /Certificate/ }
  certs.each do |cert|
    next if cert[:ciAttributes][:pfx_enable].nil? || cert[:ciAttributes][:pfx_enable] == 'false'
    data = cert[:ciAttributes][:ssl_data]
    password = cert[:ciAttributes][:ssl_password]
    ssl_certificate_exist = true
  end

  enable_cookie = cookie_enabled?(ag_service)

  # Gateway SSL Certificate
  if ssl_certificate_exist
    if data == '' || password == ''
      OOLog.fatal("PFX Data or Password is nil or empty. Data = #{data} - Password = #{password}")
    end
    application_gateway.set_ssl_certificate(data, password)
  end

  # Cookies must be enabled in case of SSL offload.
  enable_cookie = ssl_certificate_exist == true ? true : enable_cookie
  application_gateway.set_https_settings(enable_cookie)

  # Gateway Front Port
  application_gateway.set_gateway_port(ssl_certificate_exist)

  # Gateway Frontend IP Configuration
  application_gateway.set_frontend_ip_config(public_ip, gateway_subnet)

  # Gateway Listener
  application_gateway.set_listener(ssl_certificate_exist)

  # Gateway Request Route Rule
  application_gateway.set_gateway_request_routing_rule

  # Gateway SKU
  sku_name = ag_service[:ciAttributes][:gateway_size]
  application_gateway.set_gateway_sku(sku_name)

  gateway_result = application_gateway.create_or_update(location, ssl_certificate_exist)

  if gateway_result.nil?
    # Application Gateway was not created.
    OOLog.fatal("Application Gateway '#{ag_name}' could not be created")
  else
    ag_ip = express_route_enabled ? application_gateway.frontend_ip_configurations[0].private_ip_address : public_ip.ip_address

    if ag_ip.nil? || ag_ip == ''
      OOLog.fatal("Application Gateway '#{gateway_result.name}' NOT configured with IP")
    else
      OOLog.info("AzureAG IP: #{ag_ip}")
      node.set[:azure_ag_ip] = ag_ip
    end
  end
rescue => e
  OOLog.fatal("Error creating Application Gateway: #{e.message}")
end
