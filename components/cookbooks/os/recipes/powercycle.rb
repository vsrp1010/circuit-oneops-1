require 'fog'

include_recipe "shared::set_provider_new"

ruby_block 'compute powercycle' do
  block do
  
    instance_id = node.workorder.ci[:ciAttributes][:instance_id]
    server = node.iaas_provider.servers.get instance_id
    
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
    task_state = server.os_ext_sts_task_state || ""
    puts "***RESULT:task_state="+task_state
    vm_state = server.os_ext_sts_vm_state || ""
    puts "***RESULT:vm_state="+server.os_ext_sts_vm_state

  end
end
