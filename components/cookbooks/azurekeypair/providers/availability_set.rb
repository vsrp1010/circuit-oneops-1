
def whyrun_supported?
  true
end

use_inline_resources

action :create do
  converge_by('Adding Avaialbility Set') do
    as_manager = AzureBase::AvailabilitySetManager.new(@new_resource.node)
    as_manager.add
  end

  @new_resource.updated_by_last_action(true)
end
