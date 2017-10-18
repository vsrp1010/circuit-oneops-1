
def exit_with_error(msg)
	puts "***FAULT:FATAL=#{msg}"
	Chef::Application.fatal!(msg)
end

def get_azure_storage_service(creds, resource_group, storage_account_name)
  creds[:azure_storage_access_key] = Fog::Storage::AzureRM.new(creds).get_storage_access_keys(resource_group, storage_account_name)[1].value
  creds[:azure_storage_account_name] = storage_account_name
  return Fog::Storage::AzureRM.new(creds)
end