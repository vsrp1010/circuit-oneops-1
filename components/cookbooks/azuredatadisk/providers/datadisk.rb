action :create do
  creds, rg_name, storage_account_name, rg_name_persistent_storage, instance_name, device_maps = get_datadisk_params_from_node(@new_resource.node)
  dd_manager = Datadisk.new(creds, rg_name, storage_account_name, rg_name_persistent_storage, instance_name, device_maps)
  dd_manager.set_storage_account_service(creds)
  dd_manager.create
end

action :destroy do
  creds, rg_name, storage_account_name, rg_name_persistent_storage, instance_name, device_maps = get_datadisk_params_from_node(@new_resource.node)
  dd_manager = Datadisk.new(creds, rg_name, storage_account_name, rg_name_persistent_storage, instance_name, device_maps)
  dd_manager.set_storage_account_service(creds)
  dd_manager.delete_datadisk
end

action :attach do
  creds, rg_name, storage_account_name, rg_name_persistent_storage, instance_name, device_maps = get_datadisk_params_from_node(@new_resource.node)
  dd_manager = Datadisk.new(creds, rg_name, storage_account_name, rg_name_persistent_storage, instance_name, device_maps)
  dd_manager.set_storage_account_service(creds)
  dd_manager.attach
end

action :detach do
  creds, rg_name, storage_account_name, rg_name_persistent_storage, instance_name, device_maps = get_datadisk_params_from_node(@new_resource.node)
  dd_manager = Datadisk.new(creds, rg_name, storage_account_name, rg_name_persistent_storage, instance_name, device_maps)
  dd_manager.set_storage_account_service(creds)
  dd_manager.detach
end

def get_datadisk_params_from_node(node_obj)
  rg_manager = AzureBase::ResourceGroupManager.new(node_obj)
  @device_maps = nil

  if node_obj['device_map'] != nil
    @device_maps = node_obj['device_map'].split(' ')
  elsif node_obj['workorder']['rfcCi']['ciAttributes'][:device_map] != nil
    @device_maps = node_obj['workorder']['rfcCi']['ciAttributes'][:device_map].split(' ')
  end

  OOLog.info("App Name is: #{node_obj[:app_name]}")
  case node_obj[:app_name]
    when /storage/
      @device_maps.each do |dev|
        @rg_name_persistent_storage = dev.split(':')[0]
        @storage_account_name = dev.split(':')[1]
        break
      end

      node_obj.workorder.payLoad[:DependsOn].each do |dep|
        if dep['ciClassName'] =~ /Compute/
          @instance_name = dep[:ciAttributes][:instance_name]
        end
      end
    when /volume/
      node_obj.workorder.payLoad[:DependsOn].each do |dep|
        if dep['ciClassName'] =~ /Storage/
          OOLog.info('storage dependson found')
          OOLog.info('storage not NIL')
          @device_maps = dep[:ciAttributes]['device_map'].split(' ')
          @device_maps.each do |dev|
            @rg_name_persistent_storage = dev.split(':')[0]
            @storage_account_name = dev.split(':')[1]
            break
          end
          break
        end
      end

      if node_obj['workorder']['payLoad'].has_key?('ManagedVia')
        @instance_name = node_obj['workorder']['payLoad']['ManagedVia'][0]['ciAttributes']['instance_name']
      end
    when /compute/
      @rg_name_persistent_storage = node_obj['platform-resource-group']
      @storage_account_name = node_obj['storage_account']
    else
      # type code here
  end

  return rg_manager.creds, rg_manager.rg_name, @storage_account_name, @rg_name_persistent_storage, @instance_name, @device_maps
end