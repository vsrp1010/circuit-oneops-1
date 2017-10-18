# Copyright 2016, Walmart Stores, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# storage::delete
#

max_retry_count = 5
cloud_name = node[:workorder][:cloud][:ciName]
provider_class = node[:workorder][:services][:storage][cloud_name][:ciClassName].downcase
include_recipe "shared::set_provider_new"

dev_map = node[:workorder][:rfcCi][:ciAttributes][:device_map]
return if dev_map.nil?

if provider_class =~ /azure/
  #require File.expand_path('../../../azure_base/libraries/utils.rb', __FILE__)
  Utils.set_proxy(node[:workorder][:payLoad][:OO_CLOUD_VARS])
  rg_manager = AzureBase::ResourceGroupManager.new(node)
  resource_group = rg_manager.rg_name
  instance_name = node[:workorder][:payLoad][:DependsOn].select{|d| (d[:ciClassName].split('.').last == 'Compute') }.first[:ciAttributes][:instance_name]
  server = node[:storage_provider].servers(resource_group: resource_group).get(resource_group, instance_name)
end

dev_map.split(" ").each do |dev|
    if provider_class =~ /azure/ && dev.split(":").size == 5
      resource_group_name, storage_account_name, ciID, slice_size, dev_id = dev.split(':')
      vol_id = [ciID, 'datadisk',dev.split('/').last.to_s].join('-')
    else
      vol_id = dev.split(":")[0]
    end
    Chef::Log.info("destroying: "+vol_id)
    ok = false
    retry_count = 0
    while !ok && retry_count < max_retry_count do
      ok = true
      volume = nil
      begin
        if provider_class =~ /azure/ && vol_id =~ /datadisk/
          volume = server.data_disks.select{|dd| (dd.name == vol_id)}[0]
        elsif provider_class =~ /azure/ && vol_id !~ /datadisk/
          volume = node.storage_provider.managed_disks.get(resource_group, vol_id)
        else
          volume = node.storage_provider.volumes.get vol_id
        end
      rescue => e
        Chef::Log.error("getting volume exception: "+e.message)
        next
      end

      begin
        if provider_class =~ /azure/ && vol_id =~ /datadisk/ && !volume.nil?
          Chef::Log.info("Detaching unmanaged data disk")
          server.detach_data_disk(volume.name)        
        elsif provider_class =~ /azure/ && volume.respond_to?('owner_id') && !volume.owner_id.nil?
          Chef::Log.info("Detaching managed data disk")
          server.detach_managed_disk(volume.name)
        elsif !volume.nil?
          data = { 'os-detach' => { 'volume_id' => "#{vol_id}" } }
          node.storage_provider.action(vol_id, data)
        end
      rescue => e
        Chef::Log.error("getting volume detach exception: "+e.message)
      end

      begin
        if provider_class =~ /azure/ && vol_id =~ /datadisk/
          #Unmanaged disks
          vhd_blobname = storage_account_name + '-' + vol_id + ".vhd"
          storage_service = get_azure_storage_service(rg_manager.creds, resource_group_name, storage_account_name)
          storage_service.delete_disk(vhd_blobname, options = {})

        elsif !volume.nil?
          volume.destroy
        end
      rescue => e
        if e.message !~ /does not exist|Storage Unit must be in the Active or Failed state/
          Chef::Log.error("volume destroy exception: "+e.message);
          ok = false
        end
      end 

      retry_count += 1
      if !ok            
        sleep_sec = retry_count * 5
        Chef::Log.error("sleeping #{sleep_sec}sec between retries...")
        sleep(sleep_sec) 
      end
    end
    if !ok
      error_key=JSON.parse(e.response[:body]).keys[0]
      msg = JSON.parse(e.response[:body])[error_key]['message']
      exit_with_error "couldnt destroy: #{vol_id} because #{msg} .. #{error_key}"
    end
end #dev_map.split(" ").each do |dev|
