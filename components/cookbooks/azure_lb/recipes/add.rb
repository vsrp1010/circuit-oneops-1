# set the proxy if it exists as a cloud var
Utils.set_proxy(node.workorder.payLoad.OO_CLOUD_VARS)

# get platform resource group and availability set
include_recipe 'azure::get_platform_rg_and_as'

# ==============================================================

def create_publicip(cred_hash, location, resource_group_name)
  pip_svc = AzureNetwork::PublicIp.new(cred_hash)
  pip_svc.location = location
  public_ip_address = pip_svc.build_public_ip_object(node.workorder.rfcCi.ciId, 'lb_publicip')
  pip = pip_svc.create_update(resource_group_name, public_ip_address.name, public_ip_address)
  pip
end

def get_probes_from_wo
  ci = {}
  ci = node.workorder.key?('rfcCi') ? node.workorder.rfcCi : node.workorder.ci
  listeners = get_listeners()

  ecvs = []
  ecvs_raw = JSON.parse(ci[:ciAttributes][:ecv_map])
  if ecvs_raw && listeners
    OOLog.fatal('LB Listeners and ECVs are not the same length. Bad LB configuration!') unless ecvs_raw.length == listeners.count

    ecvs_raw.each do |item|
      # each item is an array
      port = item[0].to_i
      pathParts = item[1].split(' ')
      request_path = pathParts[1]

      probe_name = "Probe#{port}"
      interval_secs = 15
      num_probes = 3

      the_listener = nil
      listeners.each do |listener|
        listen_port = listener[:iport].to_i
        if listen_port == port
          the_listener = listener
          break
        end
      end

      if the_listener && (the_listener[:iprotocol].upcase == 'TCP' || the_listener[:iprotocol].upcase == 'HTTPS')
        protocol = 'Tcp'
        request_path = nil # If Protocol is set to TCP, this value MUST BE NULL.
      else
        protocol = 'Http'
      end

      ecvs.push(
          probe_name: probe_name,
          interval_secs: interval_secs,
          num_probes: num_probes,
          port: port,
          protocol: protocol,
          request_path: request_path
      )
    end
  end

  ecvs
end

def get_probes
  probes = []
  ecvs = get_probes_from_wo

  ecvs.each do |ecv|
    probe = AzureNetwork::LoadBalancer.create_probe(ecv[:probe_name], ecv[:protocol], ecv[:port], ecv[:interval_secs], ecv[:num_probes], ecv[:request_path])
    OOLog.info("Probe name: #{ecv[:probe_name]}")
    OOLog.info("Probe protocol: #{ecv[:protocol]}")
    OOLog.info("Probe port: #{ecv[:port]}")
    OOLog.info("Probe path: #{ecv[:request_path]}")
    probes.push(probe)
  end

  probes
end

def get_listeners_from_wo
  listeners = Array.new

  if node["loadbalancers"]
    raw_data = node['loadbalancers']
    raw_data.each do |listener|
      listeners.push(listener)
    end
  end

  listeners
end

def get_listeners
  ci = {}
  ci = node.workorder.key?('rfcCi') ? node.workorder.rfcCi : node.workorder.ci

  listeners = []

  if ci
    listeners_raw = ci['ciAttributes']['listeners']
    ciId = ci['ciId']

    listeners = []

    if listeners_raw
      listener_map = JSON.parse(listeners_raw)

      listener_map.each do |item|
        parts = item.split(' ')
        vproto = parts[0]
        vport = parts[1]
        iproto = parts[2]
        iport = parts[3]

        listen_name = "listener-#{ciId}_#{vproto}_#{vport}_#{iproto}_#{iport}"
        OOLog.info("Listener name: #{listen_name}")
        OOLog.info("Listener vprotocol: #{vproto}")
        OOLog.info("Listener vport: #{vport}")
        OOLog.info("Listener iprotocol: #{iproto}")
        OOLog.info("Listener iport: #{iport}")

        listener = {
            name: listen_name,
            iport: iport,
            vport: vport,
            vprotocol: vproto,
            iprotocol: iproto
        }

        listeners.push(listener)
      end
    end
    return listeners
  end

  listeners
end

def get_loadbalancer_rules(subscription_id, resource_group_name, lb_name, env_name, platform_name, probes, frontend_ipconfig_id, backend_address_pool_id)
  lb_rules = []

  ci = {}
  ci = node.workorder.key?('rfcCi') ? node.workorder.rfcCi : node.workorder.ci

  listeners = get_listeners()

  listeners.each do |listener|
    lb_rule_name = "#{env_name}.#{platform_name}-#{listener[:vport]}_#{listener[:iport]}tcp-#{ci[:ciId]}-lbrule"
    frontend_port = listener[:vport]
    backend_port = listener[:iport]
    protocol = 'Tcp'
    load_distribution = 'Default'

    ### Select the right probe for the lb rule. Ports must match
    probe_port = nil
    the_probe = nil
    probes.each do |probe|
      back_port = backend_port.to_i
      probe_port = probe[:port].to_i

      if back_port == probe_port
        the_probe = probe
        break
      end
    end
    probe_id = "/subscriptions/#{subscription_id}/resourceGroups/#{resource_group_name}/providers/Microsoft.Network/loadBalancers/#{lb_name}/probes/#{the_probe[:name]}"
    lb_rule = AzureNetwork::LoadBalancer.create_lb_rule(lb_rule_name, load_distribution, protocol, frontend_port, backend_port, probe_id, frontend_ipconfig_id, backend_address_pool_id)
    OOLog.info("LB Rule: #{lb_rule_name}")
    OOLog.info("LB Rule Frontend port: #{frontend_port}")
    OOLog.info("LB Rule Backend port: #{backend_port}")
    OOLog.info("LB Rule Protocol: #{protocol}")
    OOLog.info("LB Rule Probe port: #{probe_port}")
    OOLog.info("LB Rule Load Distribution: #{load_distribution}")
    lb_rules.push(lb_rule)
  end

  lb_rules
end

def get_dc_lb_names
  platform_name = node.workorder.box.ciName
  environment_name = node.workorder.payLoad.Environment[0]['ciName']
  assembly_name = node.workorder.payLoad.Assembly[0]['ciName']
  org_name = node.workorder.payLoad.Organization[0]['ciName']

  cloud_name = node.workorder.cloud.ciName
  dc = node.workorder.services['lb'][cloud_name][:ciAttributes][:location] + '.'
  dns_zone = node.workorder.services['dns'][cloud_name][:ciAttributes][:zone]
  dc_dns_zone = dc + dns_zone
  platform_ciId = node.workorder.box.ciId.to_s

  vnames = {}
  listeners = get_listeners_from_wo
  listeners.each do |listener|
    frontend_port = listener[:vport]

    service_type = listener[:vprotocol]
    service_type = 'SSL' if service_type == 'HTTPS'
    dc_lb_name = [platform_name, environment_name, assembly_name, org_name, dc_dns_zone].join('.') +
        '-' + service_type + '_' + frontend_port + 'tcp-' + platform_ciId + '-lb'

    vnames[dc_lb_name] = nil
  end

  vnames
end

def get_compute_nodes_from_wo
  compute_nodes = []
  computes = node.workorder.payLoad.DependsOn.select { |d| d[:ciClassName] =~ /Compute/ }
  if computes
    # Build computes nodes to load balance
    computes.each do |compute|
      compute_nodes.push(
          ciId: compute[:ciId],
          ipaddress: compute[:ciAttributes][:private_ip],
          hostname: compute[:ciAttributes][:hostname],
          instance_id: compute[:ciAttributes][:instance_id],
          instance_name: compute[:ciAttributes][:instance_name],
          allow_port: get_allow_rule_port(compute[:ciAttributes][:allow_rules])
      )
    end
  end

  compute_nodes
end

# This method constructs two arrays.
# NAT Rule array
# Compute NAT Rule.
# The second array is used to easily get the compute info along with its associated NAT rule
def get_compute_nat_rules(frontend_ipconfig_id, nat_rules, compute_natrules)
  compute_nodes = get_compute_nodes_from_wo
  if compute_nodes.count > 0
    port_increment = 10
    port_counter = 1
    front_port = 0
    OOLog.info('Configuring NAT Rules ...')
    compute_nodes.each do |compute_node|
      idle_min = 5
      nat_rule_name = "NatRule-#{compute_node[:ciId]}-#{compute_node[:allow_port]}tcp"
      front_port = (compute_node[:allow_port].to_i * port_increment) + port_counter
      frontend_port = front_port
      backend_port = compute_node[:allow_port].to_i
      protocol = 'Tcp'

      OOLog.info("NAT Rule Name: #{nat_rule_name}")
      OOLog.info("NAT Rule Front port: #{frontend_port}")
      OOLog.info("NAT Rule Back port: #{backend_port}")

      nat_rule = AzureNetwork::LoadBalancer.create_inbound_nat_rule(nat_rule_name, protocol, frontend_ipconfig_id, frontend_port, backend_port)
      nat_rules.push(nat_rule)

      compute_natrules.push(
          instance_id: compute_node[:instance_id],
          instance_name: compute_node[:instance_name],
          nat_rule: nat_rule
      )
      port_counter += 1
    end

    OOLog.info("Total NAT rules: #{nat_rules.count}")

  end

  nat_rules
end

def get_allow_rule_port(allow_rules)
  port = 22 # Default port
  unless allow_rules.nil?
    rulesParts = allow_rules.split(' ')
    rulesParts.each do |item|
      port = item.gsub!(/\D/, '') if item =~ /\d/
    end
  end

  port
end

# ==============================================================
# Variables

cloud_name = node.workorder.cloud.ciName

lb_service = nil
lb_service = node.workorder.services['lb'][cloud_name] unless node.workorder.services['lb'].nil?

OOLog.fatal('Missing lb service! Cannot continue.') if lb_service.nil?

location = lb_service[:ciAttributes][:location]
tenant_id = lb_service[:ciAttributes][:tenant_id]
client_id = lb_service[:ciAttributes][:client_id]
client_secret = lb_service[:ciAttributes][:client_secret]
subscription_id = lb_service[:ciAttributes][:subscription]

# Determine if express route is enabled
xpress_route_enabled = true
if lb_service[:ciAttributes][:express_route_enabled].nil?
  # We cannot assume express route is enabled if it is not set
  xpress_route_enabled = false
elsif lb_service[:ciAttributes][:express_route_enabled] == 'false'
  xpress_route_enabled = false
end

platform_name = node.workorder.box.ciName
environment_name = node.workorder.payLoad.Environment[0]['ciName']
resource_group_name = node['platform-resource-group']

plat_name = platform_name.gsub(/-/, '').downcase
env_name = environment_name.gsub(/-/, '').downcase
lb_name = "lb-#{plat_name}"

# ===== Create a LB =====
#   # LB Creation Steps
#
#   # 1 - Create Public IP (VIP)
#   # 2 - Create frontend IP address pool
#   # 3 - Create backend IP address pool
#   # 4 - Probes
#   # 5 - LB Rules
#   # 6 - Inbound NAT rules
#   # 7 - Create LB

public_ip = nil
subnet = nil
creds = {
    tenant_id: tenant_id,
    client_secret: client_secret,
    client_id: client_id,
    subscription_id: subscription_id
}

# Public IP
if xpress_route_enabled

  vnet_name = lb_service[:ciAttributes][:network]
  master_rg = lb_service[:ciAttributes][:resource_group]

  vnet_svc = AzureNetwork::VirtualNetwork.new(creds)
  vnet_svc.name = vnet_name
  vnet = vnet_svc.get(master_rg)

  OOLog.fatal("Could not retrieve vnet '#{vnet_name}' from express route") if vnet.nil?

  OOLog.fatal("VNET '#{vnet_name}' does not have subnets") if vnet.subnets.count < 1

  subnets = vnet.subnets
  subnet = vnet_svc.get_subnet_with_available_ips(subnets, xpress_route_enabled)

else
  # Public IP Config
  public_ip = create_publicip(creds, location, resource_group_name)
  OOLog.info("PublicIP created. PIP: #{public_ip.name}")
end

# Frontend IP Config
frontend_ipconfig_name = 'LB-FrontEndIP'
frontend_ipconfig = AzureNetwork::LoadBalancer.create_frontend_ipconfig(frontend_ipconfig_name, public_ip, subnet)
frontend_ipconfig_id = "/subscriptions/#{subscription_id}/resourceGroups/#{resource_group_name}/providers/Microsoft.Network/loadBalancers/#{lb_name}/frontendIPConfigurations/#{frontend_ipconfig_name}"
frontend_ipconfigs = []
frontend_ipconfigs.push(frontend_ipconfig)

# Backend Address Pool
backend_address_pool_name = 'LB-BackEndAddressPool'
backend_address_pool_id = "/subscriptions/#{subscription_id}/resourceGroups/#{resource_group_name}/providers/Microsoft.Network/loadBalancers/#{lb_name}/backendAddressPools/#{backend_address_pool_name}"

backend_address_pools = []
backend_address_pool_ids = []
backend_address_pools.push(backend_address_pool_name)
backend_address_pool_ids.push(backend_address_pool_id)

# ECV/Probes
probes = get_probes

# Listeners/LB Rules
lb_rules = get_loadbalancer_rules(subscription_id, resource_group_name, lb_name, env_name, platform_name, probes, frontend_ipconfig_id, backend_address_pool_id)

# Inbound NAT Rules
compute_natrules = []
nat_rules = []
get_compute_nat_rules(frontend_ipconfig_id, nat_rules, compute_natrules)

# Configure LB properties
load_balancer = AzureNetwork::LoadBalancer.get_lb(resource_group_name, lb_name, location, frontend_ipconfigs, backend_address_pools, lb_rules, nat_rules, probes)

# Create LB
lb_svc = AzureNetwork::LoadBalancer.new(creds)

lb = nil
begin
  lb = lb_svc.create_update(load_balancer)
  OOLog.info("Load Balancer '#{lb_name}' created!")
rescue
end

if lb.nil?
  OOLog.fatal("Load Balancer '#{lb_name}' could not be created")
elsif compute_natrules.empty?
  OOLog.info('No computes found for load balanced')
else
  vm_svc = AzureCompute::VirtualMachine.new(creds)
  nic_svc = AzureNetwork::NetworkInterfaceCard.new(creds)
  nic_svc.rg_name = resource_group_name
  nic_svc.location = location

  # Traverse the compute-natrules
  compute_natrules.each do |compute|
    # Get the azure VM
    vm = vm_svc.get(resource_group_name, compute[:instance_name])

    if vm.nil?
      OOLog.info("VM Not Fetched: '#{compute[:instance_name]}' ")
      next # could not find VM. Nothing to be done; skipping
    else
      # the asumption is that each VM will have only one NIC
      nic_id = vm.network_interface_card_id
      nic_name = nic_svc.get_nic_name(nic_id)
      # nic = nic_svc.get(resource_group_name, nic_name)
      nic = nic_svc.get(nic_name)

      if nic.nil?
        next # Could not find NIC. Nothing to be done; skipping
      else
        # Update the NIC with LB info - Associate VM with LB
        nic.load_balancer_backend_address_pools_ids = backend_address_pool_ids
        compute_nat_rules_id = "/subscriptions/#{subscription_id}/resourceGroups/#{resource_group_name}/providers/Microsoft.Network/loadBalancers/#{lb_name}/inboundNatRules/#{compute[:nat_rule][:name]}"
        nic.load_balancer_inbound_nat_rules_ids = [compute_nat_rules_id]
        nic_svc.create_update(nic)
      end
    end
  end # end of compute_natrules loop
end # end of main lb IF

lbip = nil
if xpress_route_enabled
  lbip = lb.frontend_ip_configurations[0].private_ipaddress
else
  pip_svc = AzureNetwork::PublicIp.new(creds)
  public_ip = pip_svc.get(resource_group_name, public_ip.name)
  lbip = public_ip.ip_address unless public_ip.nil?
end

if lbip.nil? || lbip == ''
  OOLog.fatal("Load Balancer '#{lb.name}' NOT configured with IP")
else
  OOLog.info("AzureLB IP: #{lbip}")
  node.set['azurelb_ip'] = lbip
  vnames = get_dc_lb_names

  vnames.keys.each do |key|
    vnames[key] = lbip
  end
  puts "***RESULT:vnames=#{vnames.to_json}"
end
