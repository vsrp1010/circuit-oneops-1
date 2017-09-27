require 'fog/azurerm'
require 'chef'

require ::File.expand_path('../../../azure_base/libraries/logger', __FILE__)

# module to contain classes for dealing with the Azure Network features.
module AzureNetwork
  # this class should contain methods to manipulate public ip address
  # within Azure.
  class PublicIp
    attr_accessor :location, :network_client
    attr_reader :creds, :subspriction


    def initialize(creds)
      @network_client = Fog::Network::AzureRM.new(creds)
    end

    # this will build the public_ip object to be used for creating a public
    # ip in azure
    def build_public_ip_object(ci_id, name = 'publicip')
      public_ip_address = Fog::Network::AzureRM::PublicIp.new
      public_ip_address.location = @location
      public_ip_address.idle_timeout_in_minutes = 5
      public_ip_address.name = Utils.get_component_name(name, ci_id)
      public_ip_address.public_ip_allocation_method = Fog::ARM::Network::Models::IPAllocationMethod::Dynamic
      OOLog.info("Public IP name is: #{public_ip_address.name}")
      public_ip_address
    end

    # this fuction gets the public ip from azure for the given
    # resource group and pip name
    def get(resource_group_name, public_ip_name)
      OOLog.info("Fetching public IP '#{public_ip_name}' from '#{resource_group_name}' ")
      start_time = Time.now.to_i
      begin
        response = @network_client.public_ips.get(resource_group_name, public_ip_name)
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Exception trying to get public ip #{public_ip_name} from resource group: #{resource_group_name}, Exception: #{e.body}")
      rescue => e
        OOLog.fatal("Exception trying to get public ip #{public_ip_name} from resource group: #{resource_group_name}, Exception: #{e.message}")
      end
      end_time = Time.now.to_i
      duration = end_time - start_time
      OOLog.info("operation took #{duration} seconds")
      response unless response.nil?
    end

    # this function deletes the public ip
    def delete(resource_group_name, public_ip_name)
      OOLog.info("Deleting public IP '#{public_ip_name}' from '#{resource_group_name}' ")
      start_time = Time.now.to_i
      begin
        public_ip = @network_client.public_ips.get(resource_group_name, public_ip_name)
        result = !public_ip.nil? ? public_ip.destroy : Chef::Log.info('AzureNetwork::PublicIp - 404 code, trying to delete something that is not there.')
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error deleting PublicIP '#{public_ip_name}' in ResourceGroup '#{resource_group_name}'. Exception: #{e.body}")
      rescue => e
        OOLog.fatal("Error deleting PublicIP '#{public_ip_name}' in ResourceGroup '#{resource_group_name}'. Exception: #{e.message}")
      end
      end_time = Time.now.to_i
      duration = end_time - start_time
      OOLog.info("operation took #{duration} seconds")
      result
    end

    # this function creates or updates the public ip address
    # it expects the resource group, name of the pip and public ip object
    # to already be created.
    def create_update(resource_group_name, public_ip_name, public_ip_address)
      OOLog.info("Creating/Updating public IP '#{public_ip_name}' from '#{resource_group_name}' ")
      @location = public_ip_address.location
      start_time = Time.now.to_i
      begin
        response = @network_client.public_ips.create(name: public_ip_name, resource_group: resource_group_name, location: @location, public_ip_allocation_method: public_ip_address.public_ip_allocation_method, domain_name_label: public_ip_address.domain_name_label, idle_timeout_in_minutes: public_ip_address.idle_timeout_in_minutes)
      rescue MsRestAzure::AzureOperationError => ex
        OOLog.fatal("Exception trying to create/update public ip #{public_ip_address.name} from resource group: #{resource_group_name}.  Exception: #{ex.body}")
      rescue => e
        OOLog.fatal("Exception trying to create/update public ip #{public_ip_address.name} from resource group: #{resource_group_name}.  Exception: #{e.message}")
      end
      end_time = Time.now.to_i
      duration = end_time - start_time
      OOLog.info("operation took #{duration} seconds")
      response
    end

    # this function checks whether the public ip belongs to the given
    # resource group
    def check_existence_publicip(resource_group_name, public_ip_name)
      OOLog.info("Checking existance of public IP '#{public_ip_name}' in '#{resource_group_name}' ")
      start_time = Time.now.to_i
      begin
        response = @network_client.public_ips.check_public_ip_exists(resource_group_name, public_ip_name)
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Azure::PublicIp - Exception is: #{e.body}")
      rescue => e
        OOLog.fatal("Exception trying to get public ip #{public_ip_name} from resource group: #{resource_group_name}. Exception: #{e.message}")
      end
      end_time = Time.now.to_i
      duration = end_time - start_time
      OOLog.info("operation took #{duration} seconds")
      response
    end
  end
end
