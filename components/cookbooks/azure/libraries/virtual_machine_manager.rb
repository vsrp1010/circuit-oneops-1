module AzureCompute
  class VirtualMachineManager
    attr_accessor :compute_service,
                  :initial_user,
                  :private_ip,
                  :ip_type,
                  :compute_ci_id,
                  :resource_group_name,
                  :server_name,
                  :creds,
                  :compute_client,
                  :storage_profile,
                  :network_profile,
                  :virtual_machine_lib,
                  :availability_set_response

    def initialize(node)
      @cloud_name = node['workorder']['cloud']['ciName']
      @compute_service = node['workorder']['services']['compute'][@cloud_name]['ciAttributes']
      @keypair_service = node['workorder']['payLoad']['SecuredBy'].first
      @server_name = node['server_name']
      @resource_group_name = node['platform-resource-group']
      @location = @compute_service[:location]
      @initial_user = @compute_service[:initial_user]
      @express_route_enabled = @compute_service['express_route_enabled']
      @secgroup_name = node['workorder']['payLoad']['DependsOn'][0]['ciName']
      @image_id = node['image_id'].split(':')
      @size_id = node[:size_id]
      @ip_type = node['ip_type']
      @platform = @compute_service[:ostype].include?('windows') ? 'windows' : 'linux'
      @platform_ci_id = node['workorder']['box']['ciId']
      @compute_ci_id = node['workorder']['rfcCi']['ciId']

      @creds = {
          tenant_id: @compute_service[:tenant_id],
          client_secret: @compute_service[:client_secret],
          client_id: @compute_service[:client_id],
          subscription_id: @compute_service[:subscription]
      }

      @compute_client = Fog::Compute::AzureRM.new(@creds)
      @network_client = Fog::Network::AzureRM.new(@creds)
      @virtual_machine_lib = AzureCompute::VirtualMachine.new(@creds)
      @storage_profile = AzureCompute::StorageProfile.new(@creds)
      @network_profile = AzureNetwork::NetworkInterfaceCard.new(@creds)
      @availability_set_response = @compute_client.availability_sets.get(@resource_group_name, @resource_group_name)
    end

    def create_or_update_vm
      OOLog.info('Resource group name: ' + @resource_group_name)

      @ip_type = 'public'
      @ip_type = 'private' if @express_route_enabled == 'true'
      OOLog.info('ip_type: ' + @ip_type)

      @storage_profile.resource_group_name = @resource_group_name
      @storage_profile.location = @location
      @storage_profile.size_id = @size_id
      @storage_profile.ci_id = @platform_ci_id
      @storage_profile.server_name = @server_name


      if (defined?(node[:workorder][:rfcCi][:ciAttributes][:private_ip]) && node[:workorder][:rfcCi][:rfcAction] == 'update')
        @network_profile.flag = true
        @network_profile.private_ip = node[:workorder][:rfcCi][:ciAttributes][:private_ip]
      else
        @network_profile.flag = false
      end
      @network_profile.location = @location
      @network_profile.rg_name = @resource_group_name
      @network_profile.ci_id = @compute_ci_id
      # build hash containing vm info
      # used in Fog::Compute::AzureRM::create_virtual_machine()
      vm_hash = {}

      # common values
      vm_hash[:name] = @server_name
      vm_hash[:resource_group] = @resource_group_name

      vm_hash[:availability_set_id] = @availability_set_response.id
      vm_hash[:location] = @compute_service[:location]

      # hardware profile values
      vm_hash[:vm_size] = @size_id

      # storage profile values

      vm_hash[:storage_account_name] = @storage_profile.get_managed_osdisk_name if @availability_set_response.sku_name.eql? 'Aligned'
      vm_hash[:storage_account_name] = @storage_profile.get_storage_account_name if @availability_set_response.sku_name.eql? 'Classic'
      vm_hash[:publisher] = @image_id[0]
      vm_hash[:offer] = @image_id[1]
      vm_hash[:sku] = @image_id[2]
      vm_hash[:version] = @image_id[3]

      vm_hash[:platform] = @platform

      vm_hash[:managed_disk_storage_type] = @storage_profile.get_managed_osdisk_type if @availability_set_response.sku_name.eql? 'Aligned'

      # os profile values
      vm_hash[:username] = @initial_user

      if @compute_service[:ostype].include?('windows')
        vm_hash[:password] = 'On3oP$'
      else
        vm_hash[:disable_password_authentication] = true
        vm_hash[:ssh_key_data] = @keypair_service[:ciAttributes][:public]
      end

      # network profile values
      vm_hash[:network_interface_card_ids] = @network_profile.build_network_profile(@compute_service[:express_route_enabled],
                                                                                    @compute_service[:resource_group],
                                                                                    @compute_service[:network],
                                                                                    @compute_service[:network_address].strip,
                                                                                    (@compute_service[:subnet_address]).split(','),
                                                                                    (@compute_service[:dns_ip]).split(','),
                                                                                    @ip_type,
                                                                                    @secgroup_name)

      @private_ip = @network_profile.private_ip
      # create the virtual machine
      begin
        @virtual_machine_lib.create_update(vm_hash)
      rescue MsRestAzure::AzureOperationError => e
        OOLog.debug("Error Body: #{e.body}")
        OOLog.fatal('Error creating/updating VM')
      end
    end

    def delete_vm
      OOLog.info('cloud_name is: ' + @cloud_name)
      OOLog.info('Subscription id is: ' + @compute_service[:subscription])
      start_time = Time.now.to_i
      @ip_type = 'public'
      @ip_type = 'private' if @express_route_enabled == 'true'
      OOLog.info('ip_type: ' + @ip_type)
      begin
        vm = @virtual_machine_lib.get(@resource_group_name, @server_name)
        if vm.nil?
          OOLog.info("VM '#{@server_name}' was not found. Nothing to delete. ")
          exit 1
        else

          os_disk = vm.os_disk_name

          datadisk_uri = nil
          datadisk_uri = vm.data_disks[0].vhd_uri if vm.data_disks.count > 0
          OOLog.info("Deleting Azure VM: '#{@server_name}'")
          # delete the VM from the platform resource group

          OOLog.info('VM is deleted') if @virtual_machine_lib.delete(@resource_group_name, @server_name)
        end
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error deleting VM, resource group: #{@resource_group_name}, VM name: #{@server_name}. Exception is=#{e.body}")
      rescue => ex
        OOLog.fatal("Error deleting VM, resource group: #{@resource_group_name}, VM name: #{@server_name}. Exception is=#{ex.message}")
      ensure
        end_time = Time.now.to_i
        duration = end_time - start_time
        OOLog.info("Deleting VM took #{duration} seconds")
      end

      return os_disk, datadisk_uri

    end

    def delete_unmanaged_vm
      OOLog.info('cloud_name is: ' + @cloud_name)
      OOLog.info('Subscription id is: ' + @compute_service[:subscription])
      start_time = Time.now.to_i
      @ip_type = 'public'
      @ip_type = 'private' if @express_route_enabled == 'true'
      OOLog.info('ip_type: ' + @ip_type)
      begin
        vm = @virtual_machine_lib.get(@resource_group_name, @server_name)
        if vm.nil?
          OOLog.info("VM '#{@server_name}' was not found. Nothing to delete. ")
          exit 1
        else
          # retrive the vhd name from the VM properties and use it to delete the associated VHD in the later step.
          vhd_uri = vm.os_disk_vhd_uri
          storage_account = vm.storage_account_name
          datadisk_uri = nil
          datadisk_uri = vm.data_disks[0].vhd_uri if vm.data_disks.count > 0
          OOLog.info("Deleting Azure VM: '#{@server_name}'")
          # delete the VM from the platform resource group

          OOLog.info('VM is deleted') if @virtual_machine_lib.delete(@resource_group_name, @server_name)
        end
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Error deleting VM, resource group: #{@resource_group_name}, VM name: #{@server_name}. Exception is=#{e.body}")
      rescue => ex
        OOLog.fatal("Error deleting VM, resource group: #{@resource_group_name}, VM name: #{@server_name}. Exception is=#{ex.message}")
      ensure
        end_time = Time.now.to_i
        duration = end_time - start_time
        OOLog.info("Deleting VM took #{duration} seconds")
      end
      return storage_account, vhd_uri, datadisk_uri
    end
  end
end
