require 'simplecov'
SimpleCov.start
require File.expand_path('../../libraries/resource_group_manager.rb', __FILE__)
require 'fog/azurerm'
require 'chef'

describe AzureBase::ResourceGroupManager do
  before do
    workorder = File.read('../azure_base/spec/node.json')
    workorder_hash = JSON.parse(workorder)

    @node = Chef::Node.new
    @node.normal = workorder_hash

    @resource_group_manager = AzureBase::ResourceGroupManager.new(@node)

    @resource_group_response = Fog::Resources::AzureRM::ResourceGroup.new(name: 'Confiz-first-try-113932-env-eus')
  end

  describe '#initialize' do
    it 'creates resource group with location' do
      expect(@resource_group_manager.location).to eq('eastus')
    end

    it 'creates resource group with region' do
      @node.normal['app_name'] = 'fqdn'

      resource_group_manager = AzureBase::ResourceGroupManager.new(@node)
      expect(resource_group_manager.location).to eq('eastus')
    end
  end

  describe '#exists?' do
    it 'checks if resource group exists' do
      allow(@resource_group_manager.resource_client).to receive_message_chain(:resource_groups, :check_resource_group_exists).and_return(@resource_group_response)
      expect(@resource_group_manager.exists?).to eq(@resource_group_response)
    end
  end

  describe '#add' do
    it 'creates the resource group if not exists' do
      allow(@resource_group_manager).to receive(:exists?).and_return(false)
      allow(@resource_group_manager.resource_client).to receive_message_chain(:resource_groups, :create).and_return(@resource_group_response)
      expect(@resource_group_manager.add).to eq(@resource_group_response)
    end
  end

  describe '#delete' do
    it 'deletes the resource group' do
      allow(@resource_group_manager.resource_client).to receive_message_chain(:resource_groups, :get, :destroy).and_return(true)
      expect(@resource_group_manager.delete).to eq(true)
    end
  end
end
