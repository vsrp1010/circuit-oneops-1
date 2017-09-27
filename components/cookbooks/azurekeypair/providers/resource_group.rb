
def whyrun_supported?
  true
end

use_inline_resources

action :create do
  converge_by('Creating Resource Group') do
    rg_manager = AzureBase::ResourceGroupManager.new(@new_resource.node)
    rg_manager.add
  end

  @new_resource.updated_by_last_action(true)
end

action :destroy do
  converge_by('Destroying Resouce Group') do
    rg_manager = AzureBase::ResourceGroupManager.new(@new_resource.node)
    rg_manager.delete
  end

  @new_resource.updated_by_last_action(true)
end
