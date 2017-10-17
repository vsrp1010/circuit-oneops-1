#
# Cookbook Name:: compute
# Recipe:: base
#
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

node.set["use_initial_user"] = true

include_recipe "shared::set_provider_new"
include_recipe "compute::ssh_port_wait"
include_recipe "compute::ssh_cmd_for_remote"

ruby_block 'wait for ssh in windows' do
  block do

    #wait until we can get a response from Windows VM
	start_time = Time.now.to_i
	i = 1
    win_ssh_failed = true
    ssh_cmd = node[:ssh_interactive_cmd].gsub("IP",node[:ip]) + "hostname > /dev/null"
    ssh_cmd = ssh_cmd.gsub("StrictHostKeyChecking=no","StrictHostKeyChecking=no -o ConnectTimeout=5") 
	Chef::Log.info("Started waiting for ssh response from #{node[:ip]}")
    Chef::Log.info("SSH command is: #{ssh_cmd}")

    #try connecting for 300 seconds
    while Time.now.to_i - start_time < 300 do
      Chef::Log.info( "Attempt:#{i} to get a valid ssh response from #{node[:ip]} ...")
      result = system(ssh_cmd)

      if result
        win_ssh_failed = false
        Chef::Log.info( "Received a valid response from #{node[:ip]}! Moving on to a next step...")
        break
      end

      Chef::Log.info( "Did not receive a valid response from #{node[:ip]}. Retrying...")
      sleep 20
      i += 1
    end #while

    if win_ssh_failed
      puts "***FATAL: SSH - we did not receive a valid response in 300 seconds"
      raise("SSH - we did not receive a valid response in 300 seconds")
    end

  end
end if node[:ostype] =~ /windows/ &&  node[:workorder][:rfcCi][:rfcAction] !~ /update/

ruby_block 'install base' do
  block do

    Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
    shell_timeout = 36000

    # install os package repos - repo_map keyed by os
    os_type = node[:ostype]
    cloud_name = node[:workorder][:cloud][:ciName]
    repo_cmds = []
    if node[:workorder][:services].has_key?("compute") &&
       node[:workorder][:services]["compute"][cloud_name][:ciAttributes].has_key?("repo_map") &&
       node[:workorder][:services]["compute"][cloud_name][:ciAttributes][:repo_map].include?(os_type)

      repo_map = JSON.parse(node[:workorder][:services]["compute"][cloud_name][:ciAttributes][:repo_map])
      repo_cmds = [repo_map[os_type]]
      Chef::Log.debug("repo_cmds: #{repo_cmds.inspect}")
    else
      Chef::Log.info("no key in repo_map for os: " + os_type);
    end

    # add repo_list from os
    if node.has_key?("repo_list") && !node[:repo_list].nil? && node[:repo_list].include?('[')
      Chef::Log.info("adding compute-level repo_list: #{node[:repo_list]}")
      repo_cmds += JSON.parse(node[:repo_list])
    end

    if repo_cmds.size > 0
      # todo: set proxy env vars - current use case not required
      cmd = node[:ssh_interactive_cmd].gsub("IP",node[:ip]) + '"'+ repo_cmds.join("; ") + '"'
      Chef::Log.info("running setup repos: #{cmd}")
      result = `#{cmd}`
      if result.to_i != 0
        puts "***FATAL: executing repo commands from the compute cloud service "+
             "repo_map attr and compute repo_list attr"
        Chef::Log.error("cmd: #{cmd} returned: #{result}")
      end
    end

    # sync cookbook dirs
    # shared cookbooks
    circuit_dir = "/opt/oneops/inductor"
    if node.has_key?("circuit_dir")
      # handle old packer dir
      circuit_dir = node[:circuit_dir].gsub("/packer","")
    end
    cookbook_path = "#{circuit_dir}/shared/"
    Chef::Log.info("Syncing #{cookbook_path} ...")
    cmd = node[:rsync_cmd].gsub("SOURCE",cookbook_path).gsub("DEST","~/shared/").gsub("IP",node[:ip])
    result = shell_out(cmd, :timeout => shell_timeout)
    Chef::Log.info("#{cmd} returned: #{result.stdout}")
    result.error!

    # remove first bom and last Component class
    class_parts = node[:workorder][:rfcCi][:ciClassName].split(".")
    class_parts.delete_at(0)
    class_parts.delete_at(class_parts.size-1)
    Chef::Log.debug("class parts: #{class_parts.inspect}")

    # component cookbooks
    sub_circuit_dir = "circuit-main-1"
    if class_parts.size > 0 && class_parts.first != "service"
      sub_circuit_dir = "circuit-" + class_parts.join("-")
    end
    cookbook_path = "#{circuit_dir}/#{sub_circuit_dir}/"
    node.set[:circuit_dir] = circuit_dir

    Chef::Log.info("Syncing #{cookbook_path} ...")
    cmd = node[:rsync_cmd].gsub("SOURCE",cookbook_path).gsub("DEST","~/#{sub_circuit_dir}/").gsub("IP",node[:ip])
    result = shell_out(cmd, :timeout => shell_timeout)
    Chef::Log.debug("#{cmd} returned: #{result.stdout}")
    result.error!


    # install base: oneops user, ruby, chef, nagios
    env_vars = JSON.parse(node[:workorder][:services][:compute][cloud_name][:ciAttributes][:env_vars])
    Chef::Log.info("env_vars: #{env_vars.inspect}")
    args = ""
    args_win = { }

    env_vars.each_pair do |k,v|
      args += "#{k}:#{v} "
      if k =~ /apiproxy/
        args_win[:proxy] = v
      elsif k =~ /rubygems/
        args_win[:gemrepo] = v
      end
    end

    sudo = ""
    if !node[:ssh_cmd].include?("root@")
      sudo = "sudo "
    end

    Chef::Log.info("Installing base sw for oneops ...")

    if os_type !~ /windows/
      install_base = "components/cookbooks/compute/files/default/install_base.sh"
      cmd = node[:ssh_interactive_cmd].gsub("IP",node[:ip]) + "\"#{sudo}#{sub_circuit_dir}/#{install_base} #{args}\""

      Chef::Log.info("Executing Command: #{cmd}")
      result = shell_out(cmd, :timeout => shell_timeout)

      Chef::Log.debug("#{cmd} returned: #{result.stdout}")
      result.error!

    else
      # install base: oneops user, ruby, chef, nagios

      if node[:workorder][:services].has_key?("mirror") &&
         node[:workorder][:services]["mirror"][cloud_name][:ciAttributes].has_key?("mirrors")

         mirror_vars = JSON.parse( node[:workorder][:services]["mirror"][cloud_name][:ciAttributes][:mirrors] )
         mirror_vars.each_pair do |k,v|
           if k =~ /chocopkg/
             args_win[:chocopkg] = v
           elsif k =~ /chocorepo/
             args_win[:chocorepo] = v
           end
         end
      else
        Chef::Log.info("Compute does not have mirror service included")
      end

      str_args = ""
      args_win.each_pair do |k,v|
        if k =~ /proxy/
          str_args += "-proxy '#{v}' "
        elsif k =~ /chocopkg/
          str_args += "-chocoPkg '#{v}' "
        elsif k =~ /chocorepo/
          str_args += "-chocoRepo '#{v}' "
        elsif k =~ /gemrepo/
          str_args += "-gemRepo '#{v}' "
        end
      end

      install_base = "components/cookbooks/compute/files/default/install_base.ps1"
      install_cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File #{sub_circuit_dir}/#{install_base} #{str_args} "
      cmd = node[:ssh_interactive_cmd].gsub("IP",node[:ip]) + install_cmd

      Chef::Log.info("Executing Command: #{cmd}")
      result = shell_out(cmd, :timeout => shell_timeout)

      Chef::Log.debug("#{cmd} returned: #{result.stdout}")
      result.error!


      user = node[:oneops_user]
      sudo_file = "/home/#{user}/circuit-oneops-1/components/cookbooks/compute/files/default/sudo"
      sudo_cmd = "cp #{sudo_file} /usr/bin "

      cmd = node[:ssh_interactive_cmd].gsub("IP",node[:ip]) + sudo_cmd
      Chef::Log.info("Executing Command: #{cmd}")
      result = shell_out(cmd, :timeout => shell_timeout)

      Chef::Log.debug("#{cmd} returned: #{result.stdout}")
      result.error!


      sudo_cmd = "chmod +x /usr/bin/sudo"
      cmd = node[:ssh_interactive_cmd].gsub("IP",node[:ip]) + sudo_cmd
      Chef::Log.info("Executing Command: #{cmd}")
      result = shell_out(cmd, :timeout => shell_timeout)

      Chef::Log.debug("#{cmd} returned: #{result.stdout}")
      result.error!

    end

    cmd = node[:ssh_cmd].gsub("IP",node[:ip]) + "\"grep processor /proc/cpuinfo | wc -l\""
    result = shell_out(cmd, :timeout => shell_timeout)
    cores = result.stdout.gsub("\n","")
    puts "***RESULT:cores=#{cores}"

    cmd = node[:ssh_cmd].gsub("IP",node[:ip]) + "\"free | head -2 | tail -1 | awk '{ print \\$2/1024 }'\""
    puts cmd
    result = shell_out(cmd, :timeout => shell_timeout)
    ram = result.stdout.gsub("\n","")
    puts "***RESULT:ram=#{ram}"

  end

end
