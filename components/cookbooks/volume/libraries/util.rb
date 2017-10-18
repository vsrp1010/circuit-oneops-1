
def exit_with_error(msg)
  puts "***FAULT:FATAL=#{msg}"
  Chef::Application.fatal!(msg)
end

def execute_command(command, force_failure = nil)
  result = Mixlib::ShellOut.new(command).run_command
  if result.error?
    if force_failure
      exit_with_error("Error in #{command}: #{result.stderr.gsub(/\n+/, '.')}")
    else
      Chef::Log.warn("Error in #{command}: #{result.stderr.gsub(/\n+/, '.')}")
    end
  end
  result
end

def get_storage()

  storage = nil
  device_map = []
  storage_name = nil

  #localizing the new algorithm to windows VMs only
  #to-do test with Linux
  if node.platform !~ /windows/
    Chef::Log.info("Matching storage for Linux VM")
    node.workorder.payLoad[:DependsOn].each do |dep|
      if dep[:ciClassName] =~ /Storage/
        storage = dep
        device_map = storage[:ciAttributes][:device_map].split(" ")
        break
      end
    end
  else
    Chef::Log.info("Matching storage for Windows VM")
    #For windows VMs - continue and try to match volume and storage components
    if node[:workorder][:rfcCi][:ciAttributes].has_key?(:based_on_storage)
      storage_name = "#{node[:workorder][:rfcCi][:ciAttributes][:based_on_storage]}-#{node[:workorder][:cloud][:ciId]}"
    end

    #Get all storages from DependsOn
    storages_all = []
    storages_all = node[:workorder][:payLoad][:DependsOn].select { |st| (st['ciClassName'] =~ /Storage/ )}

    #Get deduplicated array of storages
    storages = []
    if storages_all.size > 0
      storages_all.each {|i| storages.push({:storage=>i[:ciName],:device_map=>i[:ciAttributes][:device_map]}) }
      storages = storages.uniq
    end

    #Storages found, trying to determine which one to use
    if storages.size > 0

      #1 - Searching for storage component with the name matching based_on_storage attribute
      if !storage_name.nil?
        storage = storages.select { |st| (st[:storage] =~ /#{storage_name}/ )}

        if storage.size > 1
          exit_with_error ("Matching using based_on_storage - Incorrect amount of matching storage components: #{storage.size}")
        else
          storage = storage.first
          Chef::Log.info("Storage matched by using Based_on_Storage attribute")
        end
      end

      #2 - Searching for storage component with the name matching this volume component name - storageABC = volumeABC
      if storage.nil?
        storage = storages.select { |st| (st[:storage].sub('storage','') == node[:workorder][:rfcCi][:ciName].sub('volume','') )}
        if storage.size > 1
          exit_with_error ("Matching by component names - Incorrect amount of matching storage components: #{storage.size}")
        else
          storage = storage.first
          Chef::Log.info("Storage matched by using volume-storage component names")
        end
      end

      #3 - did not find matching storage so picking the first one - old behavior
      if storage.nil?
        storage = storages.first
      end

    end #if storages.size > 0

    if !storage.nil? && storage.has_key?(:device_map)
      device_map = storage[:device_map].split(' ')
    end

  end #if node.platform !~ /windows/ else

  return storage, device_map
end

def get_compute (instance_id)
  compute = nil
  if node[:provider_class] =~ /azure/
    compute = node[:iaas_provider].servers(resource_group: node[:resource_group]).get(node[:resource_group], instance_id)
  else
    compute = node[:iaas_provider].servers.get(instance_id)
  end
  return compute
end

def get_volume (vol_id, instance_id = nil)
  volume = nil
  if node[:storage_provider_class] =~ /azuredatadisk/
    if vol_id =~ /datadisk/ 
      volume = get_compute(instance_id).data_disks.select{|dd| (dd.name == vol_id)}[0]
    else
      volume = node[:storage_provider].managed_disks.get(node[:resource_group], vol_id)
    end

  elsif node[:storage_provider_class] =~ /cinder/
    volume = node[:iaas_provider].volumes.get vol_id
  else
    volume = node[:storage_provider].volumes.get vol_id
  end
  return volume
end

def get_volume_status (volume)
  status = nil
  if node[:storage_provider_class] =~ /azuredatadisk/
    if (volume.respond_to?('name') && volume.name =~ /datadisk/) || (volume.respond_to?('owner_id') && !volume.owner_id.nil?)
      status = 'attached'
    else
      status = 'detached'
    end
  elsif node[:storage_provider_class] =~ /cinder/
    status = volume.status
  else
    status = volume.state
  end
  return status.downcase
end

def get_device_id (orig_device_list, dev_prefix, max_retry_count, sleep_sec)
  #device_list is an array of devices under /dev/#dev_prefix* folder, prior to executing attach command
  #the function is called after attach command was issued on the storage provider
  #the below code watches /dev folder on the local VM and compares it to the device_list array
  #once a difference is found, it's assumed to be the new device id
  device_list = execute_command("ls -1 /dev/#{dev_prefix}*").stdout.split("\n")
  retry_count = 0
  while (orig_device_list.size + 1) != device_list.size && retry_count < max_retry_count do
    sleep sleep_sec
    retry_count +=1
    device_list = execute_command("ls -1 /dev/#{dev_prefix}*").stdout.split("\n")
  end

  if retry_count == max_retry_count && (orig_device_list.size + 1) != device_list.size
    exit_with_error("max retry count of "+max_retry_count.to_s+" hit ... device list: "+orig_device_list.inspect.gsub("\n"," "))
    exit 1
  end

  dev_id = (device_list - orig_device_list).first
  return dev_id
end
