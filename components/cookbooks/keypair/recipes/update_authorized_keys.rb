#
# handles:
# case when pre-existing (prior to keypair component) envs pulled design and got keypair
# updates: key changed

is_kp_by_zone = false
needs_update = false

ci = node[:workorder][:rfcCi]
public_key = node[:keypair][:public]
old_public_key = nil


# ok to use the public_ip for this existing group
node[:workorder][:payLoad][:secures].each do |compute|

  ip = nil
  # use public_ip (ec2) or private_ip (openstack) 
  if compute[:ciAttributes].has_key?(:public_ip)
    ip = compute[:ciAttributes][:public_ip]
  elsif compute[:ciAttributes].has_key?(:private_ip)
    ip = compute[:ciAttributes][:private_ip]
  end

  # standard keypair::add will skip here
  if ip.nil?
    Chef::Log.info("no ip - no update required")
    next
  end

  if ( ci.has_key?("ciBaseAttributes") && ci["ciBaseAttributes"].has_key?("public") ) &&
         ci["ciBaseAttributes"]["public"] != ci["ciAttributes"]["public"]

    old_public_key = ci["ciBaseAttributes"]["public"]
    old_private_key = ci["ciBaseAttributes"]["private"]

    private_key_filename = "/opt/oneops/tmp/"+ (0..16).to_a.map{|a| rand(16).to_s(16)}.join
    File.open(private_key_filename, 'w') {|f| f.write(old_private_key) }
    execute "chmod 600 #{private_key_filename}"
    needs_update = true

  end


  if needs_update

    ssh_cmd = "ssh -i #{private_key_filename} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null oneops@#{ip}"

    # add new - can return 255 when its already done
    execute "#{ssh_cmd} \"echo '#{public_key}' >> ~/.ssh/authorized_keys\"" do
      returns [0,255]
    end
    Chef::Log.info("added new public key")

    # remove old  - can return 255 when its already done    
    execute "#{ssh_cmd} \"grep -v '#{old_public_key}' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.new ; mv ~/.ssh/authorized_keys.new  ~/.ssh/authorized_keys; chmod 600  ~/.ssh/authorized_keys\"" do
      returns [0,255]
    end
    Chef::Log.info("removed old public key")

    # cleanup non-zone key
    if !is_kp_by_zone
      execute "rm #{private_key_filename}"
    end

  end

end