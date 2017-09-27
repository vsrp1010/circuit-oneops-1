require 'azure_mgmt_resources'
require File.expand_path('../../../azure_base/libraries/logger.rb', __FILE__)

::Chef::Recipe.send(:include, Azure::ARM::Resources)
::Chef::Recipe.send(:include, Azure::ARM::Resources::Models)

# Module for Azure resource groups
module AzureResources
  # class to handle operations on the Azure Resource Group
  class ResourceGroup
    def initialize(compute_service)
      creds =
        Utils.get_credentials(compute_service[:tenant_id],
                              compute_service[:client_id],
                              compute_service[:client_secret]
                             )

      @client = Azure::ARM::Resources::ResourceManagementClient.new(creds)
      @client.subscription_id = compute_service[:subscription]
    end

    # this method will create/update the resource group with the info passed in
    def add(rg_name, location)
      begin
        resource_group = Azure::ARM::Resources::Models::ResourceGroup.new
        resource_group.location = location

        start_time = Time.now.to_i
        @client.resource_groups.create_or_update(rg_name,
                                                   resource_group)
        end_time = Time.now.to_i
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error creating resource group: #{e.body}")
      rescue => ex
        OOLog.fatal("Error creating resource group: #{ex.message}")
      end

      OOLog.info("Resource Group created in #{end_time - start_time} seconds")
    end

    # This method will retrieve the resource group from azure.
    def get(rg_name)
      begin
        @client.resource_groups.check_existence(rg_name)
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error getting resource group: #{e.body}")
      rescue => ex
        OOLog.fatal("Error getting resource group: #{ex.message}")
      end
    end

    # This method will delete the resource group
    def delete(rg_name)
      begin
        start_time = Time.now.to_i
        @client.resource_groups.delete(rg_name)
        end_time = Time.now.to_i
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error deleting resource group: #{e.body}")
      rescue => ex
        OOLog.fatal("Error deleting resource group: #{ex.message}")
      end

      OOLog.info("Resource Group deleted in #{end_time - start_time} seconds")
    end

    # this method will return the resource group and availability set names
    # in the correct format
    # There is a hard limit of 64 for the name in azure, so we are taking
    # 15 chars from org, assembly, env, and abbreviating the location
    # The reason we include org/assembly/env/platform/location in the name of
    # the resource group is; we needed something that would be unique for an org
    # accross the whole subscription, we want to be able to provision and
    # de-provision platforms in the same assembly / env / location without
    # destroying all of them together.
    def self.get_name(org,assembly,platform_ci_id,environment,location)
      OOLog.info("Resource Group org: #{org}")
      OOLog.info("Resource Group assembly: #{assembly}")
      OOLog.info("Resource Group Platform ci ID: #{platform_ci_id}")
      OOLog.info("Resource Group Environment: #{environment}")
      OOLog.info("Resource Group location: #{location}")
      resource_group_name = org[0..15] + '-' +
        assembly[0..15] + '-' +
        platform_ci_id.to_s + '-' +
        environment[0..15] + '-' +
        Utils.abbreviate_location(location)
      OOLog.info("Resource Group Name is: #{resource_group_name}")
      OOLog.info("Resource Group Name Length: #{resource_group_name.length}")
      resource_group_name
    end

  end
end
