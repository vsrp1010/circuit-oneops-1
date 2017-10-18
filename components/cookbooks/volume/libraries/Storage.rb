module VolumeComponent

  class Storage
    attr_accessor :storage_component,
                  :device_maps,
                  :storage_provider,
                  :compute_service,
                  :storage_service,
                  :instance_id,
                  :resource_group_name,
                  :compute,
                  :managed_disk_storage_type,
                  :storage_devices


    def initialize (node, storage_component, device_maps)

      @storage_component = storage_component
      @device_maps = device_maps
      @storage_provider = node[:storage_provider_class]
      @compute_service = node[:iaas_provider]
      @storage_service = node[:storage_provider]
      @instance_id = node[:workorder][:payLoad][:ManagedVia][0][:ciAttributes][:instance_id]
      @instance_id = node[:workorder][:payLoad][:ManagedVia][0][:ciAttributes][:instance_name] if instance_id.nil?
      @resource_group_name = nil

      #set provider specific attributes
      if @storage_provider =~ /azuredatadisk/
        Utils.set_proxy(node[:workorder][:payLoad][:OO_CLOUD_VARS])
        #AzureBase module is located in azure_base cookbook, volume::metadata.rb needs to depend on 'azure_base'
        #TO-DO we may want to store resource_group_name value somewhere (bom, local file, etc) so it can be re-used between cookbooks/recipes. 
        #that way we won't need that extra dependency on azure_base
        @resource_group_name = AzureBase::ResourceGroupManager.new(node).rg_name
      end

      @compute = get_compute(@storage_provider, @compute_service, @instance_id, @resource_group_name)
      @managed_disk_storage_type = nil
      @managed_disk_storage_type = @compute.managed_disk_storage_type if @storage_provider =~ /azuredatadisk/

      execute_command("mkdir -p /opt/oneops/storage_devices", true)
      @storage_devices = []
      @device_maps.each do |device_maps_entry|
        storage_device = StorageDevice.new(device_maps_entry, self)
        @storage_devices.push(storage_device)
      end
    end

    def get_compute(storage_provider, compute_service, instance_id, resource_group_name = nil)
     compute = nil
     if storage_provider =~ /azuredatadisk/
       compute = compute_service.servers(resource_group: resource_group_name).get(resource_group_name, instance_id)
     else
       compute = compute_service.servers.get(instance_id)
     end
      compute
    end

    def set_provider_data_all
      Chef::Log.info("Getting storage information from provider #{@storage_provider}")
      @storage_devices.each do |storage_device|
        storage_device.set_provider_data
      end
    end

  end #class Storage

  class StorageDevice
    attr_accessor :storage_id,
                  :planned_device_id,
                  :device_prefix,
                  :assigned_device_id,
                  :status,
                  :is_attached,
                  :object

    def initialize (device_maps_entry, storage)
      #device_maps_entry is an entry in device_maps, usually in form of storage_id:device (12345:/dev/sdc)
      #Parse device_maps_entry into storage_id and device_id:
      @storage = storage
      if @storage.storage_provider =~ /azuredatadisk/ && device_maps_entry.split(':').size == 5
        master_rg, storage_account_name, ciID, @slice_size, @planned_device_id = device_maps_entry.split(':')
        @storage_id = [ciID, 'datadisk', @planned_device_id.split('/').last.to_s].join('-')
      else
        @storage_id, @planned_device_id = device_maps_entry.split(':')
      end

      @device_prefix = case @storage.storage_provider
                         when /azuredatadisk/; '/dev/sd'
                         when /cinder/; '/dev/vd'
                         when /ibm/; '/dev/vd'
                         when /ec2/; '/dev/sd'
                         else '/dev/xvd'
                       end

      execute_command("touch /opt/oneops/storage_devices/#{@storage_id}", true)
      line = execute_command("cat /opt/oneops/storage_devices/#{@storage_id}", true).stdout.chop
      if line.split(':').size > 1
        @assigned_device_id = line.split(':')[1]
      else
        @assigned_device_id = nil
      end
      @status = nil
      @is_attached = false
      @object = nil
    end

    def set_provider_data
      @object = get_object_from_provider
      @status = get_status
      @is_attached = get_is_attached
    end

    def get_object_from_provider
      #Make a fog call to the provider to retrieve volume/managed_disk object
      object = nil

      if @storage.storage_provider =~ /azuredatadisk/ && !@storage.managed_disk_storage_type
        object = nil

      elsif @storage.storage_provider =~ /azuredatadisk/ && @storage.managed_disk_storage_type
        object = @storage.storage_service.managed_disks.get(@storage.resource_group_name, @storage_id)

      elsif @storage.storage_provider =~ /cinder/
        object = @storage.compute_service.volumes.get @storage_id

      else
        object = @storage.storage_service.volumes.get @storage_id
      end

      object
    end

    def get_status
      #TO-DO we may want to retire this method altogether, is_attached attribute should be enough for all processing
      status = nil
      if @storage.storage_provider =~ /azuredatadisk/
        status = nil
      elsif @storage.storage_provider =~ /cinder/
        status = @object.status
      else 
        status = @object.state
      end
      status
    end

    def get_is_attached
      is_attached = nil

      if @storage.storage_provider =~ /azuredatadisk/ && !@storage.managed_disk_storage_type
        is_attached = true if !@storage.compute.data_disks.select{|dd| (dd.name == @storage_id)}.empty?

      elsif @storage.storage_provider =~ /azuredatadisk/ && @storage.managed_disk_storage_type
        is_attached = true if @object.respond_to?('owner_id') && !@object.owner_id.nil?

      elsif @storage.storage_provider =~ /cinder/
        is_attached = true if !@object.attachments.nil? && @object.attachments.size > 0 && @object.attachments[0]['serverId'] == @storage.instance_id

      elsif @storage.storage_provider =~ /ibm/
        is_attached = true if @object.attached?
        
      elsif @storage.storage_provider =~ /rackspace/
        is_attached = true if @storage.compute.attachments[0].volume_id = @storage_id
      end

      is_attached
    end

    def attach
      orig_device_list = execute_command("ls -1 #{@device_prefix}*").stdout.split("\n")

      if @storage.storage_provider =~ /azuredatadisk/ && !@storage.managed_disk_storage_type
        @storage.compute.attach_data_disk(@storage_id, @slice_size, @storage.compute.storage_account_name)

      elsif @storage.storage_provider =~ /azuredatadisk/ && @storage.managed_disk_storage_type
        @storage.compute.attach_managed_disk(@storage_id, @storage.resource_group_name)

      elsif @storage.storage_provider =~ /cinder/
        @object.attach @storage.instance_id, @planned_device_id
      end

      @assigned_device_id = get_assigned_device_id(orig_device_list, 5, 10)
      @is_attached = get_is_attached
    end

    def get_assigned_device_id (orig_device_list, max_retry_count, sleep_sec)
      #device_list is an array of devices under /dev/#dev_prefix* folder, prior to executing attach command
      #the function is called after attach command has been issued on the storage provider
      #the below code watches /dev folder on the local VM and compares it to the device_list array
      #once a difference is found, it's assumed to be the new device id
      #the device_id value is stored in /opt/oneops/storage_devices/@storage_id file, to provide persistence between runs
      device_list = execute_command("ls -1 #{@device_prefix}*").stdout.split("\n")
      retry_count = 0
      while (orig_device_list.size + 1) != device_list.size && retry_count < max_retry_count do
        sleep sleep_sec
        retry_count +=1
        device_list = execute_command("ls -1 #{@device_prefix}*").stdout.split("\n")
      end

      if retry_count == max_retry_count && (orig_device_list.size + 1) != device_list.size
        Chef::Log.error("Original device list: #{orig_device_list.inspect.gsub("\n"," ")}, latest device list: #{device_list.inspect.gsub("\n"," ")} ")
        exit_with_error("Device_id could not be assigned in #{max_retry_count.to_s} attemts. ")
      end

      assigned_device_id = (device_list - orig_device_list).first
      Chef::Log.info("Device_id has been assigned to: #{assigned_device_id}")
      
      execute_command("echo '#{@planned_device_id}:#{assigned_device_id}' > /opt/oneops/storage_devices/#{@storage_id}", true)
      assigned_device_id
    end

    def detach
      if @storage.storage_provider =~ /azuredatadisk/ && !@storage.managed_disk_storage_type
        @storage.compute.detach_data_disk(@storage_id)
      elsif @storage.storage_provider =~ /azuredatadisk/ && @storage.managed_disk_storage_type
        @storage.compute.detach_managed_disk(@storage_id)
      end
      @is_attached = get_is_attached
    end

  end #class StorageDevice

end #module VolumeComponent