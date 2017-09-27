require 'simplecov'
SimpleCov.start
require File.expand_path('../../libraries/availability_set_manager.rb', __FILE__)
require 'fog/azurerm'
require 'chef'

describe AzureBase::AvailabilitySetManager do
  before do
    workorder = File.read('../azure_base/spec/node.json')
    workorder_hash = JSON.parse(workorder)

    node = Chef::Node.new
    node.normal = workorder_hash

    @availability_set_manager = AzureBase::AvailabilitySetManager.new(node)

    @availability_set_response = Fog::Compute::AzureRM::AvailabilitySet.new(name: 'Confiz-first-try-113932-env-eus', resource_group: 'Confiz-first-try-113932-env-eus')
  end

   describe '#get' do
    it 'does not raise exception; returns nil or valid response' do
      allow(@availability_set_manager.compute_client).to receive_message_chain(:availability_sets, :get).and_return(@availability_set_response)
      expect(@availability_set_manager.get).to eq(@availability_set_response)
    end
  end

  describe '#add' do
    it 'creates availability set' do
      allow(@availability_set_manager.compute_client).to receive_message_chain(:availability_sets, :check_availability_set_exists).and_return(false)
      allow(@availability_set_manager.compute_client).to receive_message_chain(:availability_sets, :create).and_return(@availability_set_response)
      expect(@availability_set_manager.add).to eq(@availability_set_response)
    end
  end
end
