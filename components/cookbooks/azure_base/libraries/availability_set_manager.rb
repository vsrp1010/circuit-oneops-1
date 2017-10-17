require File.expand_path('../../libraries/resource_group_manager.rb', __FILE__)
require File.expand_path('../../libraries/logger.rb', __FILE__)
require File.expand_path('../../libraries/utils.rb', __FILE__)

module AzureBase
  # Add/Get/Delete operations of availability set
  class AvailabilitySetManager < AzureBase::ResourceGroupManager
    attr_accessor :as_name,
                  :compute_client

    def initialize(node)
      super(node)
      # set availability set name same as resource group name
      @as_name = @rg_name
      @compute_client = Fog::Compute::AzureRM.new(@creds)
    end

    # method will get the availability set using the resource group and
    # availability set name
    # will return whether or not the availability set exists.
    def get
      begin
        @compute_client.availability_sets.get(@rg_name, @as_name)
      rescue MsRestAzure::AzureOperationError => e
        # if the error is that the availability set doesn't exist,
        # just return a nil
        if e.response.status == 404
          puts 'Availability Set Not Found!  Create It!'
          return nil
        end
        OOLog.fatal("Error getting availability set: #{e.body}")
      rescue => ex
        OOLog.fatal("Error getting availability set: #{ex.message}")
      end
    end

    # this method will add the availability set if needed.
    # it first checks to make sure the availability set exists,
    # if not, it will create it.
    def add
      # check if it exists
      as_exist = @compute_client.availability_sets.check_availability_set_exists(@rg_name, @as_name)
      if as_exist
        OOLog.info("Availability Set #{@as_name} exists in the #{@location} region.")
      else
        # need to create the availability set
        OOLog.info("Creating Availability Set '#{@as_name}' in #{@location} region")

        begin
          #if we are using the managed disk attached to vm availability set needs to setup use_managed_disk to true


          @compute_client.availability_sets.create(resource_group: @rg_name, name: @as_name, location: @location, use_managed_disk: true, platform_fault_domain_count: Utils.get_fault_domains(@location
          ), platform_update_domain_count: Utils.get_update_domains)
        rescue MsRestAzure::AzureOperationError => e
          OOLog.fatal("Error adding an availability set: #{e.body}")
        rescue => ex
          OOLog.fatal("Error adding an availability set: #{ex.message}")
        end
      end
    end
  end
end
