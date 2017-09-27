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
require 'json'

include_recipe "shared::set_provider"

include_recipe "compute::ssh_cmd_for_remote"

# separate ssh commands due to lenth issues
# will be removed when os is separated from compute component

ostype = ''
begin
  ostype = node[:workorder][:payLoad][:os][0][:ciAttributes]['ostype']
rescue
  begin
    ostype = node[:workorder][:ci][:ciAttributes]['ostype']
  rescue
    ostype = node[:platform]
  end
end


ruby_block 'repair agent' do
  block do
    
    Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
    
    if ostype =~ /windows/
      #resync time with ntp server
      cmd = "net start w32time & w32tm /resync /force"
      rc = shell_out("#{node[:ssh_cmd]} \"#{cmd}\"")
      Chef::Log.debug("#{cmd} returned: #{rc.stdout}")
	  rc.error!	  
	  
	  #Kill nagios and LSF, restart the services
      [ {:process => 'nagios', :service => 'nagios'},
        {:process => 'logstash-forwarder', :service => 'perf-agent'}].each do |a|
  
        cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./circuit-oneops-1/components/cookbooks/compute/files/default/service_hard_restart.ps1 -processName '#{a[:process]}' -serviceName '#{a[:service]}' "
        rc = shell_out("#{node[:ssh_cmd]} \"#{cmd}\"")
		Chef::Log.debug("#{cmd} returned: #{rc.stdout}")
        rc.error!

      end
    
	else	
		
    nagios_reset_cmd = "sudo pkill -f '^/usr/sbin/nagios -d' ; sudo /sbin/service nagios restart"
    nagios_reset = shell_out("#{node[:ssh_cmd]} \"#{nagios_reset_cmd}\"")
    puts nagios_reset.stdout
    if nagios_reset.stderr.include? "Permission denied"
      puts "***TAG:repair=permission"
    end
    nagios_reset.error!


    # time
    if node[:workorder][:services].has_key?(:ntp)
      # ntpdate depricated ; ntpd -g runs standard now
      time_cmd = "sudo service ntpd restart"
      time_result = shell_out("#{node[:ssh_cmd]} \"#{time_cmd}\"")
      Chef::Log.info("time repaired via ntpd -g: #{time_result.stdout}")
      time_result.error!
    else
      Chef::Log.info("no ntp cloud service ; not running ntpd -g")
    end
    
    # flume agent : check version, update mgmt_domain, restart
    
    # check for updated agent for java rr dns
    init_script = "/etc/init.d/perf-agent"
    agent_rr_fix_check_cmd = "grep nameservice #{init_script}"    
    agent_rr_fix_check = shell_out("#{node[:ssh_cmd]} \"#{agent_rr_fix_check_cmd}\"")
    
    begin
      agent_rr_fix_check.error!
      Chef::Log.info("agent ok")
    rescue Exception => e
      source_file = "/opt/oneops/inductor/packer/components/cookbooks/compute/files/release/flume-0.9.4/bin/agent"
      Chef::Log.info("agent updated")
      if File::exist?(source_file)
        agent_rr_fix_cmd = node[:scp_cmd].gsub("SOURCE",source_file).gsub("DEST","~/")
        Chef::Log.info("agent update cmd: "+agent_rr_fix_cmd)
        agent_rr_fix = shell_out(agent_rr_fix_cmd)
        agent_rr_fix.error!

        agent_rr_fix_cmd = "#{node[:ssh_cmd]} \"sudo mv /home/oneops/agent #{init_script}\""
        agent_rr_fix = shell_out(agent_rr_fix_cmd)
        agent_rr_fix.error!        
      end
    end

    # fix retail wrapper so prevent issue when fs is full and cannot write offset file
    retail_file_client = "/opt/flume/bin/retail_dashf"
    agent_dos_fix_check_cmd = "grep root_used #{retail_file_client}"    
    agent_dos_fix_check = shell_out("#{node[:ssh_cmd]} \"#{agent_dos_fix_check_cmd}\"")
    
    begin
      agent_dos_fix_check.error!
      Chef::Log.info("retail_dashf ok")
    rescue Exception => e
      retail_file = "/opt/oneops/inductor/packer/components/cookbooks/compute/files/release/flume-0.9.4/bin/retail_dashf"
      Chef::Log.info("retail_dashf updated")
      if File::exist?(retail_file)
        agent_dos_fix_cmd = node[:scp_cmd].gsub("SOURCE",retail_file).gsub("DEST","~/")
        Chef::Log.info("retail update cmd: "+agent_dos_fix_cmd)
        agent_dos_fix = shell_out(agent_dos_fix_cmd)
        agent_dos_fix.error!

        agent_dos_fix_cmd = "#{node[:ssh_cmd]} \"sudo mv /home/oneops/retail_dashf #{retail_file_client}\""
        agent_dos_fix = shell_out(agent_dos_fix_cmd)
        agent_dos_fix.error!        
      end
    end


    
    # update mgmt_domain
    mgmt_domain_file = "/opt/oneops/mgmt_domain"
    mgmt_domain_update_cmd = "sudo chown oneops #{mgmt_domain_file} ; echo #{node[:mgmt_domain]} > #{mgmt_domain_file}"
    mgmt_domain_update = shell_out("#{node[:ssh_cmd]} \"#{mgmt_domain_update_cmd}\"")
    mgmt_domain_update.error!
    
    # restart agent
    agent_reset_cmd = "sudo rm -fr /opt/flume/log ; sudo /sbin/service perf-agent restart"
    agent_reset = shell_out("#{node[:ssh_cmd]} \"#{agent_reset_cmd}\"")
    puts agent_reset.stdout
    if agent_reset.stdout.include? "not starting because root is"
      puts "***TAG:repair=root_fs_full"
    elsif agent_reset.stdout.include? "java not found"
      puts "***TAG:repair=java_not_found"  
    end
    agent_reset.error!
    
    
    # dhclient check applicable only when disable was deselected
    if node[:workorder][:ci][:ciAttributes][:dhclient] == 'true'
      Chef::Log.info("dhclient usage is in effect ... starting dhclient")
      dhclient_up_cmd = "pgrep -f '^/sbin/dhclient' || sudo /sbin/dhclient"
      dhclient_up=shell_out("#{node[:ssh_cmd]} \"#{dhclient_up_cmd}\"")
      puts dhclient_up.stdout
      dhclient_up.error!
    else
      Chef::Log.info("dhclient NOT in effect shall not start dhclient")
    end
    
    # until os or postfix is modeled elsewhere a postfix repair happens here
    postfix_reset = "sudo /sbin/service postfix restart "
    var_log_messages = "sudo chmod a+r /var/log/messages "
    
    postfix_var_log = shell_out("#{node[:ssh_cmd]} \"#{var_log_messages}; #{postfix_reset} ; true\"")
    puts postfix_var_log.stdout
    postfix_var_log.error!
    run_context.include_recipe "compute::ssh_key_file_rm"

    end
  end
end
