require 'chef'

require ::File.expand_path('../../../azure_base/libraries/logger', __FILE__)


# module to contain classes for dealing with the Azure Network features.
module AzureNetwork
  # Class that defines the functions for manipulating virtual networks in Azure
  class VirtualNetwork
    attr_accessor :location,
                  :name,
                  :address,
                  :sub_address,
                  :dns_list,
                  :network_client
    attr_reader :creds, :subscription

    def initialize(creds)
      @creds = creds
      @network_client = Fog::Network::AzureRM.new(creds)
    end

    # this method creates the vnet object that is later passed in to create
    # the vnet
    def build_network_object
      OOLog.info("network_address: #{@address}")

      ns_list = []
      @dns_list.each do |dns_list|
        OOLog.info('dns address[' + @dns_list.index(dns_list).to_s + ']: ' + dns_list.strip)
        ns_list.push(dns_list.strip)
      end

      subnet = AzureNetwork::Subnet.new(@creds)
      subnet.sub_address = @sub_address
      subnet.name = @name
      sub_nets = subnet.build_subnet_object

      virtual_network = Fog::Network::AzureRM::VirtualNetwork.new
      virtual_network.location = @location
      virtual_network.address_prefixes = [@address]
      virtual_network.dns_servers = ns_list unless ns_list.nil?
      virtual_network.subnets = sub_nets
      virtual_network
    end

    # this will create/update the vnet
    def create_update(resource_group_name, virtual_network)
      OOLog.info("Creating Virtual Network '#{@name}' ...")
      start_time = Time.now.to_i
      array_of_subnets = get_array_of_subnet_hashes(virtual_network.subnets)

      begin
        response = @network_client.virtual_networks.create(name: @name,
                                                           location: virtual_network.location,
                                                           resource_group: resource_group_name,
                                                           subnets: array_of_subnets,
                                                           dns_servers: virtual_network.dns_servers,
                                                           address_prefixes: virtual_network.address_prefixes)
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Failed creating/updating vnet: #{@name} with exception #{e.body}")
      rescue => ex
        OOLog.fatal("Failed creating/updating vnet: #{@name} with exception #{ex.message}")
      end
      end_time = Time.now.to_i
      duration = end_time - start_time
      OOLog.info('Successfully created/updated network name: ' + @name + "\nOperation took #{duration} seconds")
      response
    end

    # this method will return a vnet from the name given in the resource group
    def get(resource_group_name)
      OOLog.fatal('VNET name is nil. It is required.') if @name.nil?
      OOLog.info("Getting Virtual Network '#{@name}' ...")
      start_time = Time.now.to_i
      begin
        response = @network_client.virtual_networks.get(resource_group_name, @name)
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error getting virtual network: #{@name} from resource group #{resource_group_name}.  Exception: #{e.body}")
      rescue => ex
        OOLog.fatal("Error getting virtual network: #{@name} from resource group #{resource_group_name}.  Exception: #{ex.message}")
      end
      end_time = Time.now.to_i
      duration = end_time - start_time
      OOLog.info("operation took #{duration} seconds")
      response
    end

    # this method will return a list of vnets from the resource group
    def list(resource_group_name)
      OOLog.info("Getting vnets from Resource Group '#{resource_group_name}' ...")
      start_time = Time.now.to_i
      begin
        response = @network_client.virtual_networks(resource_group: resource_group_name)
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error getting all vnets for resource group. Exception: #{e.body}")
      rescue => ex
        OOLog.fatal("Error getting all vnets for resource group. Exception: #{ex.message}")
      end
      end_time = Time.now.to_i
      duration = end_time - start_time
      OOLog.info("operation took #{duration} seconds")
      response
    end

    # this method will return a list of vnets from the subscription
    def list_all
      OOLog.info('Getting subscription vnets ...')
      start_time = Time.now.to_i
      begin
        response = @network_client.virtual_networks
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error getting all vnets for the sub. Exception: #{e.body}")
      rescue => ex
        OOLog.fatal("Error getting all vnets for the sub. Exception: #{ex.message}")
      end
      end_time = Time.now.to_i
      duration = end_time - start_time
      OOLog.info("operation took #{duration} seconds")
      response
    end

    # this method will return a vnet from the name given in the resource group
    def exists?(resource_group_name)
      OOLog.fatal('VNET name is nil. It is required.') if @name.nil?
      OOLog.info("Checking if Virtual Network '#{@name}' Exists! ...")
      begin
        result = @network_client.virtual_networks.check_virtual_network_exists(resource_group_name, @name)
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error getting virtual network: #{@name} from resource group #{resource_group_name}.  Exception: #{e.body}")
      rescue => ex
        OOLog.fatal("Error getting virtual network: #{@name} from resource group #{resource_group_name}.  Exception: #{ex.message}")
      end
      result
    end

    def get_subnet_with_available_ips(subnets, express_route_enabled)
      subnets.each do |subnet|
        next if subnet.name.downcase == 'gatewaysubnet'

        OOLog.info('checking for ip availability in ' + subnet.name)
        address_prefix = subnet.address_prefix

        if express_route_enabled
          total_num_of_ips_possible = (2**(32 - address_prefix.split('/').last.to_i)) - 5 # Broadcast(1)+Gateway(1)+azure express routes(3) = 5
        else
          total_num_of_ips_possible = (2**(32 - address_prefix.split('/').last.to_i)) - 2 # Broadcast(1)+Gateway(1)
        end
        OOLog.info("Total number of ips possible is: #{total_num_of_ips_possible}")

        no_ips_inuse = subnet.ip_configurations_ids.nil? ? 0 : subnet.ip_configurations_ids.length
        OOLog.info("Num of ips in use: #{no_ips_inuse}")

        remaining_ips = total_num_of_ips_possible - no_ips_inuse
        if remaining_ips.zero?
          OOLog.info("No IP address remaining in the Subnet '#{subnet.name}'")
          OOLog.info("Total number of subnets(subnet_name_list.count) = #{subnets.count}")
          OOLog.info('checking the next subnet')
          next # check the next subnet
        else
          return subnet
        end
      end

      OOLog.fatal('***FAULT:FATAL=- No IP address available in any of the Subnets allocated. limit exceeded')
    end

    def add_gateway_subnet_to_vnet(virtual_network, gateway_subnet_address, gateway_subnet_name)
      if virtual_network.subnets.count > 1

        virtual_network.subnets.each do |subnet|
          if subnet.name == gateway_subnet_name
            OOLog.info('No need to add Gateway subnet. Gateway subnet already exist...')
            return virtual_network
          end
        end
      end

      subnet = Fog::Network::AzureRM::Subnet.new
      subnet.name = gateway_subnet_name
      subnet.address_prefix = gateway_subnet_address

      virtual_network.subnets.push(subnet)
      virtual_network
    end

    private

    def get_array_of_subnet_hashes(array_of_subnet_objs)
      subnets_array = []
      array_of_subnet_objs.each do |subnet|
        hash = {}
        subnet.instance_variables.each { |attr| hash[attr.to_s.delete('@')] = subnet.instance_variable_get(attr) }
        unless hash['attributes'].nil?
          subnets_array << hash['attributes']
        end
      end
      subnets_array
    end
  end # end of class
end
