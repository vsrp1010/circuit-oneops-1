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

require 'fog'

include_recipe "shared::set_provider_new"

cloud_name = node[:workorder][:cloud][:ciName]
provider = node[:workorder][:services][:compute][cloud_name][:ciClassName].gsub("cloud.service.","").downcase

if provider =~ /azure/
  include_recipe "azure::powercycle_node"
  if node[:hard_reboot_result] == "Error"
    e = Exception.new("no backtrace")
    e.set_backtrace("no backtrace")
    raise e
  end
    Chef::Log.info("server ready")
elsif provider =~ /vsphere/
  include_recipe "vsphere::powercycle_node"
else
  ruby_block 'compute powercycle' do
    block do

      instance_id = node[:workorder][:ci][:ciAttributes][:instance_id]
      server = node[:iaas_provider].servers.get instance_id

      if server == nil
        Chef::Log.error("cannot find server: #{instance_id}")
        puts "***TAG:repair=compute_not_found"
        e = Exception.new("no backtrace")
        e.set_backtrace("")
        raise e
      end

      Chef::Log.info("server: "+server.inspect.gsub(/\n|\<|\>|\{|\}/,""))

      adminstatus = ""
      server.metadata.each do |metadata|
         if metadata.key == "adminstatus"
           adminstatus = metadata.value
         end
      end


      if server.state == "HARD_REBOOT"
        Chef::Log.info("skipping because vm state: #{server.state}")
        puts "***TAG:repair=skiphardreboot"
      elsif adminstatus == "maintenance"
        Chef::Log.info("skipping because adminstatus: maintenance")
        puts "***TAG:repair=skipmaintenance"
      else
        server.reboot('HARD')
        Chef::Log.info("reboot in progress")
        sleep 10

        server.wait_for(Fog.timeout,5) { ready? }
        Chef::Log.info("server ready")
      end

      puts "***RESULT:instance_state="+server.state
      task_state = ""
      vm_state = ""
      if server.class.to_s == "Fog::Compute::RackspaceV2::Server"
        task_state = server.state_ext || ""
        vm_state = server.state || ""
      else
        task_state = server.os_ext_sts_task_state || ""
        vm_state = server.os_ext_sts_vm_state || ""
      end

      puts "***RESULT:task_state="+task_state
      puts "***RESULT:vm_state="+vm_state
    end
  end
end
