# module to handle everything about the azure compute
module AzureCompute
  # class that contains all methods to handle the Storage Profile needed for
  # creating a VM
  class OsProfile

    # build the OS Profile object needed to create a VM for Azure.
    def build_profile(initial_user, pub_key, server_name)
      linux_config = Azure::ARM::Compute::Models::LinuxConfiguration.new
      linux_config.disable_password_authentication = true
      linux_config.ssh = Azure::ARM::Compute::Models::SshConfiguration.new
      linux_config.ssh.public_keys = []
      linux_config.ssh.public_keys[0] =
        Azure::ARM::Compute::Models::SshPublicKey.new
      linux_config.ssh.public_keys[0].path =
        "/home/#{initial_user}/.ssh/authorized_keys"
      linux_config.ssh.public_keys[0].key_data = pub_key
      OOLog.info("Public Key is: #{pub_key}")

      os_profile = Azure::ARM::Compute::Models::OSProfile.new
      os_profile.computer_name = server_name
      OOLog.info("Computer Name is: #{os_profile.computer_name}")
      os_profile.admin_username = initial_user
      OOLog.info("Initial User is: #{os_profile.admin_username}")
      os_profile.linux_configuration = linux_config

      os_profile
    end
    def windows_build_profile(initial_user, pub_key, server_name)
      win_config = Azure::ARM::Compute::Models::WindowsConfiguration.new
      
      os_profile = Azure::ARM::Compute::Models::OSProfile.new
      os_profile.computer_name = initial_user.gsub(/[^a-zA-Z]/,"").capitalize
      os_profile.admin_password = os_profile.computer_name + "123@"
      OOLog.info("Computer Name is: #{os_profile.computer_name}")
      os_profile.admin_username = initial_user
      OOLog.info("Initial User is: #{os_profile.admin_username}")      
      os_profile.windows_configuration = win_config

      return os_profile
    end
  end
end
