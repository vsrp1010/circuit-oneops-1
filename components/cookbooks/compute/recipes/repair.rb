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

include_recipe "compute::get_ip_from_ci"
include_recipe "compute::ssh_port_wait"
monitoring_enabled = true

cloud_name = node[:workorder][:cloud][:ciName]
Chef::Log.info("Workorder: #{node[:workorder]}")
provider = node[:workorder][:services][:compute][cloud_name][:ciClassName].gsub("cloud.service.","").downcase.split(".").last
if provider =~ /azure/
  node.set["use_initial_user"] = true
  node.set['initial_user'] = 'oneops'
end

ruby_block 'repair node' do
  block do
  
  if node[:workorder]["payLoad"].has_key?("Environment") &&
     node[:workorder][:payLoad][:Environment][0][:ciAttributes].has_key?("monitoring") &&
     node[:workorder][:payLoad][:Environment][0][:ciAttributes][:monitoring] == "false"
    
    monitoring_enabled = false
  end  
  
  if node[:ssh_port_closed] == true
    
    #Computes belonging to certain platforms(couchbase) should not be rebooted. 
    #this is a temp hack to have list of packs listed here to avoid hard reboots. 
    #Note : Powercycle action can not be performed from gui if platform is in 
    #patforms_to_exclude list.
    patforms_to_exclude=%W[couchbase]  
    pack = node[:workorder][:box][:ciAttributes][:pack]
    
    if patforms_to_exclude.include? pack
      Chef::Log.info("skipping because #{pack} in platforms to exclude #{patforms_to_exclude}")
      puts "***TAG:repair=skiphardrebootplatformexcluded"    
    else
      Chef::Log.info("ssh on #{node[:ip]} down - rebooting")
      puts "***TAG:repair=reboot"
      run_context.include_recipe("compute::reboot")
    end
        
  else
    if monitoring_enabled
      Chef::Log.info("ssh on #{node[:ip]} up - repairing agent and nagios")
      puts "***TAG:repair=agentrestart"
      run_context.include_recipe("compute::repair_agent")
    else
      Chef::Log.info("ssh on #{node[:ip]} up - not repairing perf-agent because environment.monitoring=false")
      puts "***TAG:repair=norepairmonitoringdisabled"  
    end
  end
 
 end
end

