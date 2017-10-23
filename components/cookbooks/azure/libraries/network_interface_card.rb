require 'chef'
# TODO: add checks in each method for rg_name
require File.expand_path('../../../azuresecgroup/libraries/network_security_group.rb', __FILE__)
require File.expand_path('../../../azure_base/libraries/custom_exceptions.rb', __FILE__)
require ::File.expand_path('../../../azure_base/libraries/logger', __FILE__)
require 'ipaddr'

# module to contain classes for dealing with the Azure Network features.
module AzureNetwork
  # class to implement all functionality needed for an Azure NIC.
  class NetworkInterfaceCard
    attr_accessor :location, :rg_name, :private_ip, :profile, :ci_id, :network_client, :publicip, :subnet_cls, :virtual_network, :nsg, :flag, :tags
    attr_reader :creds, :subscription

    def initialize(creds)
      @network_client = Fog::Network::AzureRM.new(creds)
      @publicip = AzureNetwork::PublicIp.new(creds)
      @subnet_cls = AzureNetwork::Subnet.new(creds)
      @virtual_network = AzureNetwork::VirtualNetwork.new(creds)
      @nsg = AzureNetwork::NetworkSecurityGroup.new(creds)
    end

    # define the NIC's IP Config
    def define_nic_ip_config(ip_type, subnet)
      nic_ip_config = Fog::Network::AzureRM::FrontendIPConfiguration.new
      nic_ip_config.subnet_id = subnet.id
      nic_ip_config.private_ipallocation_method = Fog::ARM::Network::Models::IPAllocationMethod::Dynamic

      if ip_type == 'public'
        @publicip.location = @location
        # get public ip object
        public_ip_address = @publicip.build_public_ip_object(@ci_id)
        # create public ip
        public_ip_if = @publicip.create_update(@rg_name, public_ip_address.name, public_ip_address)
        # set the public ip on the nic ip config
        nic_ip_config.public_ipaddress_id = public_ip_if.id
      end

      nic_ip_config.name = Utils.get_component_name('privateip', @ci_id)
      OOLog.info("NIC IP name is: #{nic_ip_config.name}")
      nic_ip_config
    end

    # define the NIC object
    def define_network_interface(nic_ip_config)
      network_interface = Fog::Network::AzureRM::NetworkInterface.new
      network_interface.location = @location
      network_interface.name = Utils.get_component_name('nic', @ci_id)
      network_interface.ip_configuration_id = nic_ip_config.id
      network_interface.ip_configuration_name = nic_ip_config.name
      network_interface.subnet_id = nic_ip_config.subnet_id
      network_interface.public_ip_address_id = nic_ip_config.public_ipaddress_id
      network_interface.tags = @tags

      OOLog.info("Network Interface name is: #{network_interface.name}")
      network_interface
    end

    def get(nic_name)
      OOLog.info("Fetching NIC '#{nic_name}' ")
      start_time = Time.now.to_i
      begin
        nic = @network_client.network_interfaces.get(@rg_name, nic_name)
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error getting NIC: #{nic_name}. Excpetion: #{e.body}")
      rescue => ex
        OOLog.fatal("Error getting NIC: #{nic_name}. Excpetion: #{ex.message}")
      end
      end_time = Time.now.to_i
      duration = end_time - start_time
      OOLog.info("operation took #{duration} seconds")
      nic unless nic.nil?
    end

    # create or update the NIC
    def create_update(network_interface)

      OOLog.info("Updating NIC '#{network_interface.name}' ")
      start_time = Time.now.to_i
      begin
        if(@flag)
          response = @network_client.network_interfaces.get(@rg_name, network_interface.name)
        else
          response = @network_client.network_interfaces.create(name: network_interface.name,
                                                               resource_group: @rg_name,
                                                               location: network_interface.location,
                                                               subnet_id: network_interface.subnet_id,
                                                               public_ip_address_id: network_interface.public_ip_address_id,
                                                               network_security_group_id: network_interface.network_security_group_id,
                                                               ip_configuration_name: network_interface.ip_configuration_name,
                                                               private_ip_allocation_method: network_interface.private_ip_allocation_method,
                                                               load_balancer_backend_address_pools_ids: network_interface.load_balancer_backend_address_pools_ids,
                                                               load_balancer_inbound_nat_rules_ids: network_interface.load_balancer_inbound_nat_rules_ids,
                                                               tags: network_interface.tags)
        end

        end_time = Time.now.to_i
        duration = end_time - start_time
        puts("operation took #{duration} seconds")
        OOLog.info("NIC '#{network_interface.name}' was updated in #{duration} seconds")
        response
      rescue MsRestAzure::AzureOperationError => e
        error_msg = e.body.to_s
        if error_msg.include? "\"code\"=>\"SubnetIsFull\""
          raise AzureBase::CustomExceptions::SubnetIsFullError, error_msg
        elsif error_msg.include? "\"code\"=>\"ResourceNotFound\""
          Chef::Log.error('***FAULT:FATAL= NIC is no more available, please consider replacing compute')
          Chef::Log.error('***FAULT:FATAL=' + error_msg)
        else
          OOLog.fatal("Error creating/updating NIC.  Exception: #{e.body}")
        end
      rescue => ex
        OOLog.fatal("Error creating/updating NIC.  Exception: #{ex.message}")
      end
    end

    #function to check available ip belongs to which subnet
    def ip_belongs_to_subnet(subnets, available_ip)
      my_ip = IPAddr.new(available_ip)
      subnets.each do |subnet|
        OOLog.info(subnet.address_prefix)
        check = IPAddr.new(subnet.address_prefix)
        if(check.include?(my_ip))
          OOLog.info('IP belongs to subnet : '+subnet.address_prefix)
          return subnet
        end
      end
      return nil
    end

    # this manages building the network profile in preparation of creating
    # the vm.
    def build_network_profile(express_route_enabled, master_rg, pre_vnet, network_address, subnet_address_list, dns_list, ip_type, security_group_name)
      # get the objects needed to build the profile
      @virtual_network.location = @location

      # if the express route is enabled we will look for a preconfigured vnet
      if express_route_enabled == 'true'
        OOLog.info("Master resource group: '#{master_rg}'")
        OOLog.info("Pre VNET: '#{pre_vnet}'")
        # TODO: add checks for master rg and preconf vnet
        @virtual_network.name = pre_vnet
        # get the preconfigured vnet from Azure
        network = @virtual_network.get(master_rg)
        # fail if we can't find a vnet
        OOLog.fatal('Expressroute requires preconfigured networks') if network.nil?
      else
        network_name = 'vnet_' + network_address.tr('.', '_').tr('/', '_')
        OOLog.info("Using RG: '#{@rg_name}' to find vnet: '#{network_name}'")
        @virtual_network.name = network_name
        # network = @virtual_network.get(@rg_name)
        if !@virtual_network.exists?(@rg_name)
          # if network.nil?
          # set the network info on the object
          @virtual_network.address = network_address
          @virtual_network.sub_address = subnet_address_list
          @virtual_network.dns_list = dns_list

          # build the network object
          new_vnet = @virtual_network.build_network_object
          # create the vnet
          network = @virtual_network.create_update(@rg_name, new_vnet)
        else
          network = @virtual_network.get(@rg_name)
        end
      end

      subnetlist = network.subnets

      #ips from gatewaysubnet should not be used to create NICs
      subnetlist.delete_if{|s| s.name.downcase == 'gatewaysubnet'}

      begin
        # get the subnet to use for the network

        if(@flag)
          OOLog.info("getting subnet which belongs that ip")
          subnet = ip_belongs_to_subnet(subnetlist, @private_ip)
        else
          OOLog.info("checking in subnet")
          subnet = @subnet_cls.get_subnet_with_available_ips(subnetlist, express_route_enabled)
        end

        # define the NIC ip config object
        nic_ip_config = define_nic_ip_config(ip_type, subnet)

        # define the nic
        network_interface = define_network_interface(nic_ip_config)

        # include the network securtiry group to the network interface
        network_security_group = @nsg.get(@rg_name, security_group_name)
        network_interface.network_security_group_id = network_security_group.id unless network_security_group.nil?
        # create the nic
        nic = create_update(network_interface)

      rescue AzureBase::CustomExceptions::SubnetIsFullError => e
        OOLog.info("subnet is full: #{subnet.name}")
        #Azure already said that this subnet doesn't have available ips. take it out from list and look for next available subnet
        subnetlist.delete_if{|s| s.name == subnet.name}

        if(subnetlist.empty?)
          #No more subnets to try
          OOLog.fatal('No subnets with available ip addresses are found')
        else
          #retry creating NIC with next available subnet
          retry
        end
      rescue => ex
        OOLog.fatal("Error in build_network_profile.  Exception: #{ex.message}")
      end

      # retrieve and set the private ip
      @private_ip = nic.private_ip_address
      OOLog.info('Private IP is: ' + @private_ip)

      nic.id
    end

    def get_nic_name(raw_nic_id)
      nicnameParts = raw_nic_id.split('/')
      # retrieve the last part
      nic_name = nicnameParts.last

      nic_name
    end

    def delete(resource_group_name, nic_name)
      OOLog.info("Deleting NetworkInterfaceCard '#{nic_name}' from '#{resource_group_name}' ")
      start_time = Time.now.to_i
      begin
      nic_exists = !@network_client.network_interfaces(resource_group: resource_group_name).select{|nic| (nic.name == nic_name)}.empty?
      if !nic_exists
        OOLog.info("NetworkInterfaceCard '#{nic_name}' in ResourceGroup '#{resource_group_name}' was not found. Skipping deletion...")
        result = nil
      else
        nic = @network_client.network_interfaces.get(resource_group_name, nic_name)
        result = !nic.nil? ? nic.destroy : OOLog.info('AzureNetwork::NetworkInterfaceCard - 404 code, trying to delete something that is not there.')
      end
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error deleting NetworkInterfaceCard '#{nic_name}' in ResourceGroup '#{resource_group_name}'. Exception: #{e.body}")
      rescue => e
        OOLog.fatal("Error deleting NetworkInterfaceCard '#{nic_name}' in ResourceGroup '#{resource_group_name}'. Exception: #{e.message}")
      end
      end_time = Time.now.to_i
      duration = end_time - start_time
      OOLog.info("operation took #{duration} seconds")
      result
    end
  end
end
