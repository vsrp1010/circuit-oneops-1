require 'fog/azurerm'
require 'chef'

module AzureCompute
  class StorageProfile

    attr_accessor :location,
                  :resource_group_name,
                  :size_id,
                  :ci_id,
                  :server_name

    def initialize(creds)
      @storage_client =
          Fog::Storage::AzureRM.new(creds)

      @compute_client =
          Fog::Compute::AzureRM.new(creds)
    end

    def get_managed_osdisk_name
      #this is to get the OS managed disk name

      begin

        managed_osdiskname = @server_name.to_s + "managedos" + Utils.abbreviate_location(@location)
        managed_osdiskname

      rescue => e
        OOLog.fatal("Error setting up managed os disk name: #{managed_osdiskname}: #{e.message}")
      end

    end

    def get_managed_osdisk_type
      #this is to get the Managed disk type based on compute type

      if @size_id =~ /(.*)GS(.*)|(.*)DS(.*)/
        sku_name = "Premium_LRS"
      else
        sku_name = "Standard_LRS"
      end

      OOLog.info("VM size: #{@size_id}")
      OOLog.info("Storage Type: #{sku_name}")
      sku_name
    end

    def delete_managed_osdisk(resource_group_name, managed_diskname)
      # this is to delete managed OS disk

      OOLog.info("Deleting OS Managed Disk '#{managed_diskname}' in '#{resource_group_name}' ")

      begin
        OOLog.info("Deleting OS Managed Disk '#{managed_diskname}' in '#{resource_group_name}' ")
        start_time = Time.now.to_i

        os_managed_disk = @compute_client.managed_disks.get(resource_group_name, managed_diskname)
        os_managed_disk.destroy
        end_time = Time.now.to_i
        duration = end_time - start_time

      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error deleting Managed Disk '#{managed_diskname}' in ResourceGroup '#{resource_group_name}'. Exception: #{e.body}")
      rescue => e
        OOLog.fatal("Error deleting Managed Disk  '#{managed_diskname}' in ResourceGroup '#{resource_group_name}'. Exception: #{e.message}")
      end
      OOLog.info(" Deleting OS Managed disk operation took #{duration} seconds")
    end

    # Below code needs to be removed after migrating Unmanaged disk to managed disks

    def get_storage_account_name
      # create storage account if needed
      begin
        storage_account_name = create_storage_account_name()
        create_storage_account(storage_account_name)
        wait_for_storage_account(storage_account_name)
        storage_account_name
      rescue => e
        OOLog.fatal("Error creating storage account: #{storage_account_name}: #{e.message}")
      end
    end

    private

    def create_storage_account(storage_account_name)
      if storage_name_avail?(storage_account_name)
        replication = "LRS"
        if @size_id =~ /(.*)GS(.*)|(.*)DS(.*)/
          sku_name = "Premium"
        else
          sku_name = "Standard"
        end

        OOLog.info("VM size: #{@size_id}")
        OOLog.info("Storage Type: #{sku_name}_#{replication}")

        storage_account =
            @storage_client.storage_accounts.create({name: storage_account_name,
                                                     resource_group: @resource_group_name,
                                                     location: @location,
                                                     sku_name: sku_name,
                                                     replication: replication})
        if storage_account.nil?
          OOLog.fatal("***FAULT:FATAL=Could not create storage account #{storage_account_name}")
        end
      end
    end

    def wait_for_storage_account(storage_account_name)
      i = 0
      until storage_account_created?(storage_account_name) do
        if (i >= 10)
          OOLog.fatal("***FAULT:FATAL=Timeout. Could not find storage account #{storage_account_name}")
        end
        i += 1
        sleep 30
      end
    end


    def create_storage_account_name()
      # Azure storage accout name restrinctions:
      # alpha-numberic  no special characters between 9 and 24 characters
      # name needs to be globally unique, but it also needs to be per region.
      generated_name = "oostg" + @ci_id.to_s + Utils.abbreviate_location(@location)

      # making sure we are not over the limit
      if generated_name.length > 22
        generated_name = generated_name.slice!(0..21)
      end

      OOLog.info("Generated Storage Account Name: #{generated_name}")
      OOLog.info("Getting Resource Group '#{@resource_group_name}' VM count")
      vm_count = get_resource_group_vm_count
      OOLog.info("Resource Group VM Count: #{vm_count}")

      storage_accounts = generate_storage_account_names(generated_name)

      storage_index = calculate_storage_index(storage_accounts, vm_count)
      if storage_index < 0
        OOLog.fatal("No storage account can be selected!")
      end

      storage_accounts[storage_index]
    end

    # This function will generate all possible storage account NAMES
    # for current Resource Group.

    def generate_storage_account_names(storage_account_name)
      # The max number of resources in a Resource Group is 800
      # Microsoft guidelines is 40 Disks per storage account
      # to not affect performance
      # So the most storage accounts we could have per Resource Group is 800/40
      limit = 800/40

      storage_accounts = Array.new

      (1..limit).each do |index|
        if index < 10
          account_name = "#{storage_account_name}0" + index.to_s
        else
          account_name = "#{storage_account_name}" + index.to_s
        end
        storage_accounts[index-1] = account_name
      end

      storage_accounts
    end

    #Calculate the index of the storage account name array
    #based on the number of virtual machines created on the
    #current subscription
    def calculate_storage_index(storage_accounts, vm_count)
      increment = 40
      storage_account = 0
      vm_count += 1
      storage_count = storage_accounts.size - 1

      (0..storage_count).each do |storage_index|
        storage_account += increment
        if vm_count <= storage_account
          return storage_index
        end
      end
      -1
    end

    def get_resource_group_vm_count
      vm_count = 0
      vm_list = @compute_client.servers(resource_group: @resource_group_name)
      if !vm_list.nil? and !vm_list.empty?
        vm_count = vm_list.size
      else
        vm_count = 0
      end
      vm_count
    end

    def storage_name_avail?(storage_account_name)
      begin
        response =
            @storage_client.storage_accounts.check_name_availability(storage_account_name, 'Microsoft.Storage/storageAccounts')
        OOLog.info("Storage Name Available: #{response}")
      rescue MsRestAzure::AzureOperationError => e
        OOLog.info("ERROR checking availability of #{storage_account_name}")
        OOLog.info("ERROR Body: #{e.body}")
        return nil
      rescue => ex
        OOLog.fatal("Error checking availability of #{storage_account_name}: #{ex.message}")
      end
      response
    end

    def storage_account_created?(storage_account_name)
      begin
        response =
            @storage_client.storage_accounts.check_storage_account_exists(@resource_group_name, storage_account_name)
        OOLog.info("Storage Account Exists: #{response}")
      rescue MsRestAzure::AzureOperationError => e
        OOLog.info("#ERROR Body: #{e.body}")
        return false
      rescue => ex
        OOLog.fatal("Error getting properties of #{storage_account_name}: #{ex.message}")
      end
      response
    end
# Above block code needs to be removed after migrating all Unmanaged vms moved to managed VMS
  end
end
