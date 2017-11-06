
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
# storage::add
#
# adds block storage ... volume component will attach and create raid device and filesystem
#


# TODO: fix fog/aws devices to remove the /dev/[s|vx]d\d+ limitation
# only 15*8 devices available from sdi1-sdp15 (efgh used for ephemeral)
#

require File.expand_path('../../../azure_base/libraries/utils.rb', __FILE__)
require 'json'
include_recipe 'shared::set_provider'
size_config = node.workorder.rfcCi.ciAttributes["size"]
size_scale = size_config[-1,1]
size = size_config.to_i.to_s.to_i
action = node.workorder.rfcCi.rfcAction
if node.workorder.has_key?("payLoad") && node.workorder.payLoad.has_key?("volumes")
  mode = node.workorder.payLoad.volumes[0].ciAttributes["mode"]
else
  mode = "no-raid"
end

Chef::Log.info("Storage Requested : " + size_config)

if size_config == "-1"
  Chef::Log.info("Skipping Storage Allocation Due to Size is -1")
  return true
end

slice_count = node.workorder.rfcCi.ciAttributes["slice_count"].to_i
slice_count = 1 if slice_count.nil?
Chef::Log.info("size_scale: "+size_scale)
size *= 1024 if size_scale == "T"
exit_with_error("Minimum volume size should be 10G") if size < 10

if slice_count == 1
  slice_size = size.to_i
elsif mode == "no-raid" || mode == "raid0"
  slice_size = (size.to_f / slice_count.to_f).ceil
elsif mode == "raid1" || mode == "raid10"
  slice_size = (size.to_f / slice_count.to_f).ceil * 2
elsif mode == "raid5"
  slice_size = size.to_f/(slice_count.to_i-1).ceil
end

Chef::Log.info("raid10 - #{slice_count} slices of: #{slice_size}")

# Create the dev/vols and store the map to device_map attr ... volume::add will attach them to the compute
dev_list = ""
vols = Array.new
old_slice_count = slice_count
old_size = size
if action == "update"
  exit_with_error("Could not extend volume for raid mode. Recreate volumes in no-raid mode for volume extension support") if mode != "no-raid"
  if node.workorder.rfcCi.ciBaseAttributes.has_key?("size")
    old_size = node.workorder.rfcCi.ciBaseAttributes["size"]
  else
    Chef::Log.info("Storage requested is same as before. #{old_size}G")
    return true
  end
  old_slice_count = node.workorder.rfcCi.ciBaseAttributes["slice_count"].to_i if node.workorder.rfcCi.ciBaseAttributes.has_key?("slice_count")
  scale = old_size[-1,1]
  oldsize = old_size[0..-2].to_i
  size = size.to_i
  old_size = old_size.to_i
  if old_slice_count > slice_count
    exit_with_error("Slice count cant be decreased")
  else
    slice_count = slice_count - old_slice_count
    if slice_count == 0
      slice_count = 1
    end
  end
  old_size *= 1024 if scale == "T"
  if size > old_size
    slice_size = size - old_size
    exit_with_error("Size requested is too small") if slice_size < 10
  elsif size == old_size
    Chef::Log.info("Storage requested is same as before. #{old_size}G")
    return true
  else
    exit_with_error("Size of storage can not be decreased")
  end
  vols = node.workorder.rfcCi.ciAttributes["device_map"].split(" ") if node.workorder.rfcCi.ciAttributes.has_key?("device_map")
  if mode == "no-raid" || mode == "raid0"
    slice_size = (slice_size.to_f / slice_count.to_f).ceil
  else
    slice_size = (slice_size.to_f / slice_count.to_f).ceil*2
  end
end
exit_with_error("Minimum slice size should be 10G") if slice_size < 10

# openstack+kvm doesn't use explicit device names, just set and order
openstack_dev_set = ['b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v']
block_index = ""
["p","o","n","m","l","k","j","i"].each do |i|
  dev = "/dev/vxd#{i}0"
  if !::File.exists?(dev)
    block_index = i
    break
  end
end

# lame have to use the sdX device for the call but show up as xvdX (for 11.04)
Array(1..slice_count).each do |i|
  dev = ""
  if node.storage_provider_class =~ /cinder/
    dev = "/dev/vd#{openstack_dev_set[i]}"
  elsif node.storage_provider_class =~ /azure/
    dev = "/dev/sd#{openstack_dev_set[i]}"
  else
    dev = "/dev/xvd#{block_index}#{i.to_s}"
  end

  Chef::Log.info("adding dev: #{dev} size: #{slice_size}G")
  Chef::Log.info("node.storage_provider_class"+node.storage_provider_class)

  volume = nil
  case node.storage_provider_class
  when /cinder/
    begin
      include_recipe 'storage::node_lookup'
      vol_name = node["workorder"]["rfcCi"]["ciName"]+"-"+node["workorder"]["rfcCi"]["ciId"].to_s
      Chef::Log.info("Volume type selected in the storage component:"+node.volume_type_from_map)
      Chef::Log.info("Creating volume of size:#{slice_size} , volume_type:#{node.volume_type_from_map}, volume_name:#{vol_name} .... ")
      volume = node.storage_provider.volumes.new :device => dev, :size => slice_size, :name => vol_name,
        :description => dev, :display_name => vol_name, :volume_type => node.volume_type_from_map
      volume.save
    rescue Excon::Errors::RequestEntityTooLarge => e
      exit_with_error(JSON.parse(e.response[:body])["overLimit"]["message"])
    rescue Exception => e
      exit_with_error(e.message)
    end

  when /rackspace/
    begin
      vol_name = node["workorder"]["rfcCi"]["ciName"]+"-"+node["workorder"]["rfcCi"]["ciId"].to_s
      volume = node.storage_provider.volumes.new :display_name => vol_name, :size => slice_size.to_i
      volume.save
    rescue Exception => e
      Chef::Log.info("exception: "+e.inspect)
    end
  when /ibm/
    volume = node.storage_provider.volumes.new({
      :name => node.workorder.rfcCi.ciName,
      :format => "RAW",
      :location_id => "41",
      :size => "60",
      :offering_id => "20035200"
    })
    volume.save
    # takes ~5min, lets sleep 1min, then try for 10min to wait for Detached state,
    # because volume::add will error if not in Detached state
    sleep 60
    max_retry_count = 10
    retry_count = 0
    vol = node.storage_provider.volumes.get volume.id
    while vol.state != "Detached" && retry_count < max_retry_count
      sleep 60
      vol = node.storage_provider.volumes.get volume.id
      retry_count += 1
      Chef::Log.info("vol state: "+vol.state)
    end

    if retry_count >= max_retry_count
      Chef::Log.error("took more than 10minutes for volume: "+volume.id.to_s+" to be ready and still isn't")
    end

    when /azuredatadisk/

      #set the proxy if it exists as a cloud var
      Utils.set_proxy(node[:workorder][:payLoad][:OO_CLOUD_VARS])

      compute_attr = node[:workorder][:payLoad][:DependsOn].select{|d| (d[:ciClassName].split('.').last == 'Compute') }.first[:ciAttributes]
      if Utils.is_prm(compute_attr[:size], false) && node[:workorder][:rfcCi][:ciAttributes][:volume_type] == 'IOPS1'
        account_type = 'Premium_LRS'
      else
        account_type = 'Standard_LRS'
      end
      vol_name = node[:workorder][:rfcCi][:ciName] + '-' + node[:workorder][:rfcCi][:ciId].to_s + '-' + dev.split('/').last.to_s
      rg_manager = AzureBase::ResourceGroupManager.new(node)

      volume = node.storage_provider.managed_disks.create(
        name: vol_name,
        location: rg_manager.location,
        resource_group_name: rg_manager.rg_name,
        account_type: account_type,
        disk_size_gb: slice_size,
        creation_data: { create_option: 'Empty' }
      )
      Chef::Log.info("Managed disk created: #{volume.inspect.gsub("\n",'')}")

    else
    # aws
    avail_zone = ''
    node.storage_provider.describe_availability_zones.body['availabilityZoneInfo'].each do |az|
      puts "az: #{az.inspect}"
      if az['zoneState'] == 'available'
        avail_zone = az['zoneName']
        break
      end
    end
    volume = node.storage_provider.volumes.new :device => dev, :size => slice_size, :availability_zone => avail_zone
  end

  if node.storage_provider_class =~ /azure/
    volume_dev = volume.name.to_s + ':' + dev
  else
    volume_dev = volume.id.to_s + ':' + dev
  end
  Chef::Log.info("Adding #{volume_dev} to device map")
  vols.push(volume_dev)
end

puts "***RESULT:device_map="+vols.join(" ")
