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

# volume::delete
#
# unmounts, removes: raid, lv vg and detaches blockstorage
#
is_windows = false
is_windows = true if node[:platform] =~ /windows/
has_mounted = false
cloud_name = node[:workorder][:cloud][:ciName]
provider_class = node[:workorder][:services][:compute][cloud_name][:ciClassName].split(".").last.downcase
rfcAttrs = node.workorder.rfcCi.ciAttributes
platform_name = node.workorder.box.ciName
logical_name = node[:workorder][:rfcCi][:ciName]

Chef::Log.info("Platform_name         : #{platform_name}")
Chef::Log.info("Is platform windows?  : #{is_windows}")
Chef::Log.info("Provider              : #{provider_class}")

if rfcAttrs.has_key?("mount_point") && !rfcAttrs["mount_point"].empty?

  mount_point = rfcAttrs["mount_point"].gsub(/\/$/,"")
  Chef::Log.info("umount directory is: #{mount_point}")

  if !is_windows

    out = execute_command("grep #{mount_point} /etc/mtab").stdout
    if !out.empty? && !out.nil?
      has_mounted = true
    end

    package 'lsof' do
      only_if {['centos','redhat','fedora','suse'].include?(node[:platform])}
    end

    ruby_block "killing open files at #{mount_point}" do
      block do
       execute_command("lsof #{mount_point} | awk '{print $2}' | grep -v PID | uniq | xargs kill -9")
      end
      only_if { has_mounted }
    end

    execute "umount -Rf #{mount_point}" do
      only_if { has_mounted }
    end

    # clear the tmpfs ramdisk entries and/or volume entries from /etc/fstab
    if(rfcAttrs["fstype"] == "tmpfs") || provider_class =~ /azure/ || provider_class =~ /cinder/
      Chef::Log.info("clearing /etc/fstab entry for fstype tmpfs")
      execute_command("grep -v #{mount_point} /etc/fstab > /tmp/fstab")
      execute_command("mv /tmp/fstab /etc/fstab")
      execute_command("rm -rf '/opt/oneops/azure-restore-ephemeral-mntpts/#{logical_name}.sh'")
      execute_command("cp /etc/rc.local tmpfile;sed -e '/\\/opt\\/oneops\\/azure-restore-ephemeral-mntpts\\/#{logical_name}.sh/d' tmpfile > /etc/rc.local;rm -rf tmpfile")
    end
  else
    ps_volume_script = "#{Chef::Config[:file_cache_path]}/cookbooks/Volume/files/del_disk.ps1"
    cmd = "#{ps_volume_script} \"#{mount_point}\""
    Chef::Log.info("cmd:"+cmd)

    powershell_script "Remove-Windows-Volume" do
      code cmd
    end
  end #if node.platform !~ /windows/
end

ruby_block 'lvremove ephemeral' do
  only_if {::File.exists?("/dev/#{platform_name}-eph/#{logical_name}")}
  not_if {is_windows}
  block do
    execute_command("lvremove -f #{platform_name}-eph/#{logical_name}")
    execute_command("sudo rm -rf #{mount_point}")
  end
end

supported = true
if provider_class =~ /virtualbox|vagrant|docker/
  Chef::Log.info(" virtual box vagrant and docker don't support iscsi/ebs via api yet - skipping")
  supported = false
end

storage = nil
storage, device_maps = get_storage()

if storage.nil?
  Chef::Log.info("no DependsOn Storage.")
  return
end

include_recipe "shared::set_provider_new"

if (node[:provider_class] =~ /azure/)
  require File.expand_path('../../../azure_base/libraries/utils.rb', __FILE__)
  Utils.set_proxy(node[:workorder][:payLoad][:OO_CLOUD_VARS])
  node.set[:resource_group] = (AzureBase::ResourceGroupManager.new(node)).rg_name
end

raid_device = "/dev/md/"+ logical_name
ruby_block 'destroy raid' do
  only_if {::File.exists?(raid_device)}
  not_if {is_windows}
  block do
    max_retry_count = 3
    retry_count = 0

    while retry_count < max_retry_count && ::File.exists?(raid_device) do
      execute_command("mdadm --stop #{raid_device}")
      execute_command("mdadm --remove #{raid_device}")
      retry_count += 1
      if ::File.exists?(raid_device)
        Chef::Log.info("waiting 10sec for raid array to stop/remove")
        sleep 10
      end
    end

    exit_with_error("raid device still exists after many mdadm --stop #{raid_device}") if ::File.exists?(raid_device)
  end
end #ruby_block 'destroy raid' do

ruby_block 'lvremove storage' do
  block do

    if !is_windows
      execute_command("lvremove -f #{platform_name}")
    end #if !is_windows

    provider = node.iaas_provider
    storage_provider = node.storage_provider
    instance_id = node[:workorder][:payLoad][:ManagedVia][0][:ciAttributes][:instance_id]
    instance_id = node[:workorder][:payLoad][:ManagedVia][0][:ciAttributes][:instance_name] if instance_id.nil?
    Chef::Log.info("instance_id: "+instance_id)
    compute = get_compute(instance_id)

    max_retry_count = 3
    change_count = 1
    retry_count = 0
    while change_count > 0 && retry_count < max_retry_count
      change_count = 0

      device_maps.each do |dev_vol|
        vol_id,dev_id = dev_vol.split(":")
        Chef::Log.info("vol: "+vol_id)

        volume = get_volume(vol_id)
        Chef::Log.info( "volume:"+volume.inspect.gsub("\n",""))

        begin
          vol_state = get_volume_status(volume)

          if vol_state != "available" && vol_state != "detached"
            if vol_state != "detaching"
              Chef::Log.info("detaching "+vol_id)

              case provider_class
                when /openstack/
                  attached_instance_id = ""
                  Chef::Log.warn("volume: #{volume.inspect.gsub("\n","")}")
				  Chef::Log.warn("Volume attachments size: #{volume.attachments.size}, attachments: #{volume.attachments.inspect.gsub("\n","")}")
				  Chef::Log.warn("attachments: #{volume.attachments[0].inspect.gsub("\n","")}")
				  Chef::Log.warn("serverId: #{volume.attachments[0]["serverId"]}")
				  if volume.attachments.size >0
                    attached_instance_id = volume.attachments[0]["serverId"]
					Chef::Log.warn("attached_instance_id: #{attached_instance_id}")
                  end

                  if attached_instance_id != instance_id
                    Chef::Log.info("attached_instance_id: #{attached_instance_id} doesn't match this instance_id: "+instance_id)
                  else
                    volume.detach instance_id, vol_id
                    sleep 10
                    detached=false
                    detach_wait_count=0

                    while !detached && detach_wait_count<max_retry_count do
                      volume = provider.volumes.get vol_id
                      Chef::Log.info("vol state: "+volume.status)
                      if volume.status == "available"
                        detached=true
                      else
                        sleep 10
                        detach_wait_count += 1
                      end
                    end

                    #Could not detach in allocated number of tries
                    exit_with_error("Could not detach volume #{vol_id}") unless detached

                  end

                when /rackspace/
                  compute.attachments.each do |a|
                    Chef::Log.info "destroying: "+a.inspect
                    a.destroy
                  end
                when /ibm/
                  compute.detach(volume.id)
                when /azure/
                  compute.detach_managed_disk(volume.name)
                else
                  # aws uses server_id
                  if volume.server_id == instance_id
                    volume.server = nil
                  else
                    Chef::Log.info("attached_instance_id: #{volume.server_id} doesn't match this instance_id: "+instance_id)
                  end
              end

            end
            change_count += 1
          else
            Chef::Log.info( "volume available.")
          end
        rescue  => e
          exit_with_error("#{e.message}" +"\n"+ "#{e.backtrace.inspect}")
        end
      end

      Chef::Log.info("this pass detach count: #{change_count}")
      if change_count > 0
        retry_sec = retry_count*10
        Chef::Log.info( "sleeping "+retry_sec.to_s+" sec...")
        sleep(retry_sec)
      end
      retry_count += 1
    end

  end
end
