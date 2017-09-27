require 'spec_helper'
require 'json'

require File.expand_path('../../../../azure_base/libraries/resource_group_manager.rb', __FILE__)
require File.expand_path('../../../../azure_base/libraries/availability_set_manager.rb', __FILE__)

describe 'azurekeypair::delete' do
  let(:chef_run) do
    workorder = File.read('spec/workorders/keypair.json')
    workorder_hash = JSON.parse(workorder)

    chef_run = ChefSpec::SoloRunner.new(platform: 'ubuntu', version: '16.04')
    chef_run.node.consume_attributes(workorder_hash)
    chef_run
  end

  it 'adds the resource group and availability set' do
    chef_run.converge(described_recipe)
    expect(chef_run).to delete_azurekeypair_resource_group('Resource Group')
  end
end