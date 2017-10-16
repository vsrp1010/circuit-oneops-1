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
# volume::add
#

# scan for available /dev/xvd* devices from dmesg
# create a physical device in LVM (pvcreate) for each
# create a volume group vgcreate with the name of the platform
# create a logical volume lvcreate with the name of the resource /dev/<resource>
# use storage dep to gen a raid and lvm ontop

#Baremetal condition: Redirect to raid volume recipe
compute_baremetal = node.workorder.payLoad.ManagedVia[0]["ciAttributes"]["is_baremetal"]
if !compute_baremetal.nil? && compute_baremetal =~/true/
        Chef::Log.info("This is a baremetal compute. Should have RAID config")
        `sudo touch /var/tmp/expected_devices`
        include_recipe "volume::add_raid"
        return
end

if node.platform =~ /windows/
  include_recipe "volume::windows_vol_add"
  return
end

storage = nil
storage,device_maps = get_storage()
rfcCi = node[:workorder][:rfcCi]
attrs = rfcCi[:ciAttributes]

#Check raid requirements
mode = attrs[:mode]
level = mode.gsub('raid','')
if mode == 'raid0' && device_maps.size < 2
  exit_with_error("Minimum of 2 storage slices are required for #{mode}")
elsif mode == 'raid1' && (device_maps.size < 2 || device_maps.size%2 != 0)
  exit_with_error("Minimum of 2 storage slices and storage slice count mod 2 are required for #{mode}")
elsif mode == 'raid5' && device_maps.size < 3
  exit_with_error("Minimum of 3 storage slices are required for #{mode}")
elsif mode == 'raid10' && (device_maps.size < 4 || device_maps.size%2 != 0)
  exit_with_error("Minimum of 4 storage slices and storage slice count mod 2 are required for #{mode}")
end

include_recipe "shared::set_provider_new"

size = attrs[:size].gsub(/\s+/, "")
if size == '-1'
  Chef::Log.info('skipping because size = -1')
  return
end

if (node[:provider_class] =~ /azure/) && !storage.nil?
  require File.expand_path('../../../azure_base/libraries/utils.rb', __FILE__)
  Utils.set_proxy(node[:workorder][:payLoad][:OO_CLOUD_VARS])
  node.set[:resource_group] = (AzureBase::ResourceGroupManager.new(node)).rg_name
 end

package 'lvm2'
package 'mdadm' do
  not_if{mode == 'no-raid'}
end

storageUpdated = false
if !storage.nil?
   storageUpdated = storage.ciBaseAttributes.has_key?("size")
end
newDevicesAttached = ""
logical_name = rfcCi[:ciName]
raid_device = "/dev/md/#{logical_name}"
rfc_action = rfcCi[:rfcAction]
no_raid_device = " "
node.set["raid_device"] = raid_device
platform_name = node[:workorder][:box][:ciName]
token_class = node[:provider_class]

Chef::Log.info("-------------------------------------------------------------")
Chef::Log.info("Volume Size      : #{size}")
Chef::Log.info("Raid Device      : #{raid_device}")
Chef::Log.info("RFC Action       : #{rfc_action}")
Chef::Log.info("Storage Provider : #{node[:storage_provider_class]}")
Chef::Log.info("Storage          : #{storage.inspect.gsub("\n",' ')}")
Chef::Log.info("-------------------------------------------------------------")

# need ruby block so package resource above run first
ruby_block 'create-iscsi-volume-ruby-block' do
  block do

    if storage.nil?
      Chef::Log.info("no DependsOn Storage - skipping")
    else

        instance_id = node[:workorder][:payLoad][:ManagedVia][0][:ciAttributes][:instance_id]
        instance_id = node[:workorder][:payLoad][:ManagedVia][0][:ciAttributes][:instance_name] if instance_id.nil?
        Chef::Log.info("instance_id: "+instance_id)
        compute = get_compute(instance_id)
        vols = Array.new
        dev_list = ""

        device_maps.each do |dev_vol|
          vol_id, dev_id = dev_vol.split(':')
          Chef::Log.info("vol_id: "+vol_id)

          vol = get_volume(vol_id)
          Chef::Log.info("vol: "+ vol.inspect.gsub("\n"," ").gsub("<","").gsub(">","") )

          begin

            case token_class
              when /ibm/
                if vol.attached?
                  Chef::Log.error("attached already, no way to determine device")
                  # mdadm sometime reassembles with _0
                  new_raid_device = execute_command("ls -1 #{raid_device}* 2>/dev/null").stdout.chop
                  if new_raid_device.empty?
                    exit 1
                  else
                    raid_device = new_raid_device
                    node.set["raid_device"] = raid_device
                    break
                  end
                end

                # determine new device by watching /dev because ibm (kvm) doesn't attach it to the specified device
                orig_device_list = execute_command('ls -1 /dev/vd*').stdout.split("\n")
                compute.attach(vol.id)
                dev_id = get_device_id(orig_device_list, 'vd', 30, 10)
                Chef::Log.info "device: "+dev_id
                node.set["raid_device"] = dev_id

              when /openstack/
                if vol.attachments != nil && vol.attachments.size > 0 &&
                    vol.attachments[0]["serverId"] == instance_id
                  Chef::Log.error("attached already, no way to determine device")
                  # mdadm sometime reassembles with _0
                  new_raid_device = execute_command("ls -1 #{raid_device}* 2>/dev/null").stdout.chop
                  non_raid_device = execute_command("ls -1 /dev/#{platform_name}/#{logical_name}* 2>/dev/null").stdout.chop
                  if new_raid_device.empty? && non_raid_device.empty?
                    Chef::Log.warn("Cleanup Failed Attempt ")
                    vol.detach instance_id, vol_id
                    exit 1
                  else
                    if new_raid_device.empty?
                      raid_device = non_raid_device
                      no_raid_device = non_raid_device
                    else
                      raid_device = new_raid_device
                      no_raid_device = new_raid_device
                    end
                  next
                  end
                end

                Chef::Log.info("-------------------------------------------")
                Chef::Log.info("dev_id: "+dev_id)
                Chef::Log.info("Instance_id: "+instance_id)
                # determine new device by by watching /dev because openstack (kvm) doesn't attach it to the specified device
                orig_device_list = execute_command('ls -1 /dev/vd*').stdout.split("\n")
                vol.attach instance_id, dev_id
                dev_id = get_device_id(orig_device_list, 'vd', 12, 15)
                Chef::Log.info "Assigned Device: "+dev_id
                Chef::Log.info("-------------------------------------------")
                no_raid_device = dev_id

              when /rackspace/
                rackspace_dev_id = dev_id.gsub(/\d+/,"")
                is_attached = false
                compute.attachments.each do |a|
                  is_attached = true if a.volume_id = vol.id
                end
                if !is_attached
                  compute.attach_volume vol.id, rackspace_dev_id
                end

                node.set["raid_device"] = rackspace_dev_id

              when /ec2/
                vol.device = dev_id.gsub("xvd","sd")
                vol.server = compute

              when /azure/
                if vol.owner_id.nil?
                  orig_device_list = execute_command('ls -1 /dev/sd*').stdout.split("\n")
                  compute.attach_managed_disk(vol_id, node[:resource_group])
                  dev_id = get_device_id(orig_device_list, 'sd', 5, 10)
                else
                  Chef::Log.warn("Managed disk #{vol.name} is already attached to #{vol.owner_id}")
                end

            end
          rescue Fog::Compute::AWS::Error=>e
            if e.message =~ /VolumeInUse/
              Chef::Log.info("already added")
            else
              Chef::Log.info(e.inspect)
              exit 1
            end
          end
          vols.push vol_id
          dev_list += dev_id+" "
        end

        # wait until all are attached
        fin = false
        max_retry = 10
        retry_count = 0
        while !fin && retry_count<max_retry do
          fin = true
          vols.each do |vol_id|
            vol = get_volume(vol_id)
            vol_state = get_volume_status(vol)
            Chef::Log.info("vol: "+vol_id+" state:"+vol_state)

            if vol_state.downcase != "attached" && vol_state.downcase != "in-use"
              fin = false
              sleep 10
            end
          end
          retry_count +=1

        end

      newDevicesAttached = dev_list
      has_created_raid = false
      exec_count = 0
      max_retry = 10

      if vols.size > 1 && mode != 'no-raid'
        
        cmd = "yes |mdadm --create -l#{level} -n#{vols.size.to_s} --assume-clean --chunk=256 #{raid_device} #{dev_list} 2>&1"
        until ::File.exists?(raid_device) || has_created_raid || exec_count > max_retry do
          Chef::Log.info(raid_device+" being created with: "+cmd)

          out = `#{cmd}`
          exit_code = $?.to_i
          Chef::Log.info("exit_code: "+exit_code.to_s+" out: "+out)
          if exit_code == 0
            has_created_raid = true
            # really always need to readahead 64k?
            # TODO: analyze impact of 64k read-ahead - extra cost to perf
            #`blockdev --setra 65536 /dev/md/#{node.workorder.rfcCi.ciName}`
          else
            exec_count += 1
            sleep 10

            ccmd = "for f in /dev/md*; do mdadm --stop $f; done"
            Chef::Log.info("cleanup bad arrays: "+ccmd)
            Chef::Log.info(`#{ccmd}`)

            ccmd = "mdadm --zero-superblock #{dev_list}"
            Chef::Log.info("cleanup incase re-using: "+ccmd)
            Chef::Log.info(`#{ccmd}`)
          end
        end
        node.set["raid_device"] = raid_device
      else
        Chef::Log.info("No Raid Device ID :" +no_raid_device)
        raid_device = no_raid_device
        node.set["raid_device"] = no_raid_device

      end

    end

  end
end


### filesystem - check for new attr and exit for backwards compat
_mount_point = nil
_device = nil
_fstype = nil
_options = nil
if attrs.has_key?("mount_point")
  Chef::Log.info("using filesystem-in-volume logic")
  _mount_point = attrs["mount_point"]
  _device = attrs["device"]
  _options = attrs["options"]
  _fstype = attrs["fstype"]
end

if node[:platform_family] == "rhel" && node[:platform_version].to_i >= 7
  Chef::Log.info("starting the logical volume manager.")
  service 'lvm2-lvmetad' do
    action [:enable, :start]
    provider Chef::Provider::Service::Systemd
  end
end

ruby_block 'create-ephemeral-volume-on-azure-vm' do
  only_if { (storage.nil? && token_class =~ /azure/ && _fstype != 'tmpfs') }
  block do
    restore_script_dir = '/opt/oneops/azure-restore-ephemeral-mntpts'
    initial_mountpoint = '/mnt/resource'
    script_file_path   = "#{restore_script_dir}/#{logical_name}.sh"
    ephemeral_device   = '/dev/sdb1'
    rc_file_path       = '/etc/rc.d/rc.local'

    # Create restore directory with path
    `mkdir -p #{restore_script_dir}`

    l_switch = size =~ /%/ ? '-l' : '-L'
    f_switch = node[:platform_family] == 'rhel' && node[:platform_version].to_i >= 7 ? '' : '-f'

    mount_script = "#!/bin/bash\n"                                                                            \
                   "\n"                                                                                       \
                   "EXIT_SUCCESS=0\n"                                                                         \
                   "EXIT_CRITICAL=2\n"                                                                        \
                   "IS_FORMATTED=0\n"                                                                         \
                   "\n"                                                                                       \
                   "umount #{initial_mountpoint}\n"                                                           \
                   "pvcreate -f #{ephemeral_device}\n"                                                        \
                   "vgcreate #{platform_name}-eph #{ephemeral_device}\n"                                      \
                   "\"yes\" | lvcreate #{l_switch} #{size} -n #{logical_name} #{platform_name}-eph\n"         \
                   "\n"                                                                                       \
                   "mount /dev/#{platform_name}-eph/#{logical_name} #{_mount_point}\n"                        \
                   "if [ ! -d #{_mount_point}/lost+found ]; then\n"                                           \
                   "  mkfs -t #{_fstype} #{f_switch} /dev/#{platform_name}-eph/#{logical_name}\n"             \
                   "  mkdir -p #{_mount_point}\n"                                                             \
                   "  mount /dev/#{platform_name}-eph/#{logical_name} #{_mount_point}\n"                      \
                   "  $IS_FORMATTED=1\n"                                                                      \
                   "fi\n"                                                                                     \
                   "\n"                                                                                       \
                   "count=$(awk /#{logical_name}.sh/ #{rc_file_path} | wc -l)\n"                              \
                   "if [ $count == 0 ]; then\n"                                                               \
                   "  sudo echo \"sh #{script_file_path}\" >> #{rc_file_path}\n"                              \
                   "  exit_status=$EXIT_SUCCESS\n"                                                            \
                   "elif [ $IS_FORMATTED == 1 ]; then\n"                                                      \
                   "  echo 'CRITICAL - Mount Points are restored but data is lost.'\n"                        \
                   "  exit_status=$EXIT_CRITICAL\n"                                                           \
                   "else\n"                                                                                   \
                   "  exit_status=$EXIT_SUCCESS\n"                                                            \
                   "fi\n"                                                                                     \
                   "\n"                                                                                       \
                   "exit $exit_status\n"                                                                      \
                   "\n"

    Chef::Log.info("Writing mount points restoration script '#{script_file_path}'...")
    File.open(script_file_path, 'w') { |file| file.write(mount_script) }

    # Make script and rc.local files executable
    `sudo chmod +x #{script_file_path}`
    `sudo chmod +x #{rc_file_path}`

    Chef::Log.info("Executing '#{script_file_path}' script...")
    `sudo sh "#{script_file_path}"`
  end
end

ruby_block 'create-ephemeral-volume-ruby-block' do
  # only create ephemeral if doesn't depend_on storage
  not_if { token_class =~ /azure/ || _fstype == "tmpfs" || !storage.nil? }
  block do
    #get rid of /mnt if provider added it
    initial_mountpoint = "/mnt"
    has_provider_mount = false

    `grep /mnt /etc/fstab | grep cloudconfig`
    if $?.to_i == 0
      has_provider_mount = true
    end
    if token_class =~ /vsphere/
      initial_mountpoint = "/mnt/resource"
      `grep #{initial_mountpoint} /etc/fstab`
      if $?.to_i == 0
        has_provider_mount = true
      end
    end

    if has_provider_mount
      Chef::Log.info("unmounting and clearing fstab for #{initial_mountpoint}")
      `umount #{initial_mountpoint}`
      `egrep -v "\/mnt" /etc/fstab > /tmp/fstab`
      `mv -f /tmp/fstab /etc/fstab`
    end


    devices = Array.new
    # c,d are used on aws m1.medium - j,k are set on aws rhel 6.3 L
    device_set = ["b","c","d","e","f","g","h","i","j","k"]

    # aws
    device_prefix = "/dev/xvd"
    case token_class

      when /openstack/
        device_prefix = "/dev/vd"
        device_set = ["b"]
        Chef::Log.info("using openstack vdb")

      when /vsphere/
        device_prefix = "/dev/sd"
        device_set = ["b"]
        Chef::Log.info("using vsphere sdb")
    end

    df_out = `df -k`.to_s
    device_set.each do |ephemeralIndex|
      ephemeralDevice = device_prefix+ephemeralIndex
      if ::File.exists?(ephemeralDevice) && df_out !~ /#{ephemeralDevice}/
        # remove partitions - azure and rackspace add them
        `parted #{ephemeralDevice} rm 1`
        Chef::Log.info("removing partition #{ephemeralDevice}")
        devices.push(ephemeralDevice)
      end
    end

    total_size = 0
    device_list = ""
    existing_dev = `pvdisplay -s`
    devices.each do |device|
      dev_short = device.split("/").last
      if existing_dev !~ /#{dev_short}/
        Chef::Log.info("pvcreate #{device} ..."+`pvcreate -f #{device}`)
        device_list += device+" "
      end
    end

    if device_list != ""
      Chef::Log.info("vgcreate #{platform_name}-eph #{device_list} ..."+`vgcreate -f #{platform_name}-eph #{device_list}`)
    else
      Chef::Log.info("no ephemerals.")
    end

    l_switch = "-L"
    if size =~ /%/
      l_switch = "-l"
    end

    `vgdisplay #{platform_name}-eph`
    if $?.to_i == 0
      `lvdisplay /dev/#{platform_name}-eph/#{logical_name}`
      if $?.to_i != 0
        execute_command("yes | lvcreate #{l_switch} #{size} -n #{logical_name} #{platform_name}-eph",true)
      else
        Chef::Log.warn("logical volume #{platform_name}-eph/#{logical_name} already exists and hence cannot recreate .. prefer replacing compute")
      end

    end

  end
end

ruby_block 'create-storage-non-ephemeral-volume' do
  only_if { storage != nil && token_class !~ /virtualbox|vagrant/ }
  block do
    if mode != "no-raid"
      raid_devices = node.raid_device
    else
      raid_devices = newDevicesAttached
    end
    devices = Array.new
    raid_devices.split(" ").each do |raid_device|
      if ::File.exists?(raid_device)
        Chef::Log.info(raid_device+" exists.")
        devices.push(raid_device)
      else
        Chef::Log.info("raid device " +raid_device+" missing.")
        volume_device = node[:volume][:device]
        volume_device = node[:device] if volume_device.nil? || volume_device.empty?
        if node[:storage_provider_class] =~ /azure/
          Chef::Log.info("Checking for"+ volume_device + "....")
          if ::File.exists?(volume_device)
            Chef::Log.info("device " + volume_device + " found. Using this device for logical volumes.")
            devices.push(volume_device)
          else
            Chef::Log.info("No storage device named " + volume_device + " found. Exiting ...")
            exit 1
          end
        else
          exit 1
        end
      end
    end
    total_size = 0
    device_list = ""
    existing_dev = `pvdisplay -s`
    devices.each do |device|
      dev_short = device.split("/").last
      if existing_dev !~ /#{dev_short}/
        Chef::Log.info("pvcreate #{device} ..."+`pvcreate #{device}`)
        device_list += device+" "
      end
    end

    if device_list != ""
      if rfc_action != "update"
        # yes | and -ff needed sometimes
        Chef::Log.info("vgcreate #{platform_name} #{device_list} ..."+`yes | vgcreate -ff #{platform_name} #{device_list}`)
      else
        Chef::Log.info("vgextend #{platform_name} #{device_list} ..."+`yes | vgextend -ff #{platform_name} #{device_list}`)
      end
    else
      Chef::Log.info("Volume Group Exists Already")
    end

    l_switch = "-L"
    if size =~ /%/
      l_switch = "-l"
    end

    `lvdisplay /dev/#{platform_name}/#{logical_name}`

    if $?.to_i != 0
      execute_command("yes | lvcreate #{l_switch} #{size} -n #{logical_name} #{platform_name}",true)
    else
        Chef::Log.warn("logical volume #{platform_name}/#{logical_name} already exists and hence cannot recreate .. prefer replacing compute")
    end


    #lvextend will add size to existing one and extend it keeping data intact, that size should be difference between new_size and old_size
    #Conditions covered
    #1. User can extend peristent volume if space is available on storage
    #2. User can extend storage and can extend volume
    #3. Replace storage doesn't do anything, so it will not allow usre to change volume component too

    check_persistent = false
    node.workorder.payLoad[:DependsOn].each do |dep|
      if dep["ciClassName"] =~ /Storage/
        check_persistent = true
        break
      end
    end

    if ((check_persistent && rfc_action == "update" && token_class =~ /openstack/) || (rfc_action == "update" && storageUpdated))
      new_size = size
      old_size = rfcCi[:ciBaseAttributes][:size]

      #if old_size is not availabe in workorder, setting old_size from actual mount point of compute
      if old_size.nil? || old_size =~ /%/
        details = `df -h /dev/#{platform_name}/#{logical_name}`
        old_size = details.gsub(/\s+/m, ' ').strip.split(" ")[8]
      end

      #cheecks if user is increasing or decreasing size
      if new_size =~ /G/ && old_size =~ /G/
        new_size = new_size.gsub!(/[^0-9]/, '')
        old_size = old_size.gsub!(/[^0-9]/, '')
        size = new_size.to_i - old_size.to_i
        if size < 0
          exit_with_error "you cant decrese volume size"
        end
        size = size.to_s
        size = size+"G"
        Chef::Log.info("we are extending by #{size}")
      else
        Chef::Log.info("extending will consider volume")
      end

      #will not run if there is no change in updated volume size
      if (size == "0G" || ((!storageUpdated) && size =~ /%/))
        Chef::Log.info("Storage is not extended")
      else
        execute_command("yes |lvextend #{l_switch} +#{size} /dev/#{platform_name}/#{logical_name}",true)
      end

    end

    execute_command("vgchange -ay #{platform_name}",true)

  end
end


if token_class =~ /ibm/
  _fstype = "ext3"
end

package "xfsprogs" do
  only_if { _fstype == "xfs" }
end

ruby_block 'filesystem' do
  not_if { _mount_point == nil || _fstype == "tmpfs" }
  block do
    if ((token_class =~ /azure/) && (storage.nil? || storage.empty?))
      Chef::Log.info("Not creating the fstab entry for epheremal on azure compute")
      Chef::Log.info("auto mounting is being handle in rc.local, needs to be revisited.")
    else
      _device = "/dev/#{platform_name}/#{logical_name}"

      # if ebs/storage exists then use it, else use the -eph ephemeral volume
      if ! ::File.exists?(_device)
        _device = "/dev/#{platform_name}-eph/#{logical_name}"

        if ! ::File.exists?(_device)
          # micro,tiny and rackspace don't have ephemeral
          Chef::Log.info("_device #{_device} don't exists")
          next
        end
      end

      if _options == nil || _options.empty?
        _options = "defaults"
      end

      case _fstype
        when 'nfs', 'nfs4'
          include_recipe "volume::nfs"
      end

      Chef::Log.info("filesystem type: "+_fstype+" device: "+_device +" mount_point: "+_mount_point)
      # result attr updates cms
      Chef::Log.info("***RESULT:device="+_device)
      if rfc_action == "update"
        has_resized = false
        if _fstype == "xfs"
          `xfs_growfs #{_mount_point}`
          Chef::Log.info("Extending the xfs filesystem" )
          has_resized = true
        elsif (_fstype == "ext4" || _fstype == "ext3") && File.exists?("/dev/#{platform_name}/#{logical_name}")
          `resize2fs /dev/#{platform_name}/#{logical_name}`
          Chef::Log.info("Extending the filesystem" )
          has_resized = true
        end
        if has_resized && $? != 0
          exit_with_error "Error in extending filesystem"
        end
      end
      `mountpoint -q #{_mount_point}`
      if $?.to_i == 0
        Chef::Log.info("device #{_mount_point} already mounted.")
        next
      end

      type = (`file -sL #{_device}`).chop.split(" ")[1]

      Chef::Log.info("-------------------------")
      Chef::Log.info("Type : = "+type )
      Chef::Log.info("-------------------------")

      if type == "data"
        if node[:platform_family] == "rhel" && (node[:platform_version]).to_i >= 7
          cmd = "mkfs -t #{_fstype} #{_device}" # -f switch not valid in latest mkfs
        else
          cmd = "mkfs -t #{_fstype} -f #{_device}"
        end
        Chef::Log.info(cmd+" ... "+`#{cmd}`)
      end

      # in-line because of the ruby_block doesn't allow updated _device value passed to mount resource
      `mkdir -p #{_mount_point}`
      `mount -t #{_fstype} -o #{_options} #{_device} #{_mount_point}`

      # clear and add to fstab again to make sure has current attrs on update
      `grep -v #{_device} /etc/fstab > /tmp/fstab`
      ::File.open("/tmp/fstab","a") do |fstab|
        fstab.puts("#{_device} #{_mount_point} #{_fstype} #{_options} 1 1")
        Chef::Log.info("adding to fstab #{_device} #{_mount_point} #{_fstype} #{_options} 1 1")
      end
      `mv /tmp/fstab /etc/fstab` 

      if token_class =~ /azure/
        `sudo mkdir /opt/oneops/workorder`
        `sudo chmod 777 /opt/oneops/workorder`
      end
    end
  end
end

ruby_block 'ramdisk tmpfs' do
  only_if { _fstype == "tmpfs" }
  block do

    # Unmount existing mount for the same mount_point
    `mount | grep #{_mount_point}`
    if $?.to_i == 0
      Chef::Log.info("device #{_device} for mount-point #{_mount_point} already mounted.Will unmount it.")
      result=`umount #{_mount_point}`
      Chef::Log.error("umount error: #{result.to_s}") if result.to_i != 0
    end

    if _options == nil || _options.empty?
      _options = "defaults"
    end

    Chef::Log.info("mounting ramdisk :: filetype:#{_fstype} dir:#{_mount_point} device:#{_device} size:#{size} options:#{_options}")

    # Make directory if not existing
    `mkdir -p #{_mount_point}`
    result=`mount -t #{_fstype} -o size=#{size} #{_fstype} #{_mount_point}"`
    Chef::Log.error("mount error: #{result.to_s}") if result.to_i != 0

    # clear existing mount_point and add to fstab again to ensure update attributes and to persist the ramdisk across reboots
    `grep -v #{_mount_point} /etc/fstab > /tmp/fstab`
    ::File.open("/tmp/fstab","a") do |fstab|
      fstab.puts("#{_device} #{_mount_point} #{_fstype} #{_options},size=#{size}")
      Chef::Log.info("adding to fstab #{_device} #{_mount_point} #{_fstype} #{_options}")
    end
    `mv /tmp/fstab /etc/fstab`
  end
end
