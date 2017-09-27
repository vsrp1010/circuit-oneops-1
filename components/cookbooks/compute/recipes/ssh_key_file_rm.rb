ruby_block 'ssh key rm' do
  block do
     File.delete(node[:ssh_key_file])
  end
end
