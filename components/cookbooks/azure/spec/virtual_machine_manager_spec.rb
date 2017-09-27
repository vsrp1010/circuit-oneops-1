require 'json'
require 'fog/azurerm'
require 'chef'
require 'simplecov'
require File.expand_path('../../../azure_base/libraries/logger.rb', __FILE__)
SimpleCov.start

require File.expand_path('../../libraries/virtual_machine_manager', __FILE__)
require File.expand_path('../../libraries/virtual_machine', __FILE__)
require File.expand_path('../../libraries/storage_profile', __FILE__)
require File.expand_path('../../libraries/network_interface_card', __FILE__)
require File.expand_path('../../libraries/public_ip', __FILE__)
require File.expand_path('../../libraries/subnet', __FILE__)
require File.expand_path('../../../azuresecgroup/libraries/network_security_group', __FILE__)
require File.expand_path('../../libraries/virtual_network', __FILE__)
require File.expand_path('../../../azure_base/libraries/utils', __FILE__)

describe AzureCompute::VirtualMachineManager do
  before :each do
    workorder = File.read('./spec/virtual_machine_manager_spec.json')
    workorder_hash = JSON.parse(workorder)

    node = Chef::Node.new
    node.normal = workorder_hash
    @virtual_machine_manager = AzureCompute::VirtualMachineManager.new(node)
    @availability_set = Fog::Compute::AzureRM::AvailabilitySet.new
    @availability_set.id = "/subscriptions/<Subscription ID>/resourceGroups/<Test-RG>/providers/Microsoft.Compute/availabilitySets/<Test-RG>"
    @nic_id = "/subscriptions/<Subscription ID>/resourceGroups/<Test-RG>/providers/Microsoft.Network/networkInterfaces/<Test-NIC>"
    @server = Fog::Compute::AzureRM::Server.new(
        name: 'Test-server',
        location: 'eastus',
        resource_group: 'Test-RG',
        vm_size: 'Standard_A1',
        storage_account_name: 'test-storage-account',
        username: 'shaffan',
        network_interface_card_id: @nic_id,
        publisher: 'Canonical',
        offer: 'UbuntuServer',
        sku: '14.04.2-LTS',
        version: 'latest',
        os_disk_vhd_uri: 'https://test-storage-account.blob.core.windows.net/',
        data_disks: [],
        service: @virtual_machine_manager.compute_service
    )
  end

  describe '# test create or update virtual machine' do
    before do
    allow( @virtual_machine_manager.compute_client).to receive_message_chain(:availability_sets, :get).and_return(@availability_set)
    allow(@virtual_machine_manager.storage_profile).to receive(:get_storage_account_name).and_return('test-storage-account')
    allow(@virtual_machine_manager.network_profile).to receive(:build_network_profile).and_return(@nic_id)
    end
    it 'returns virtual machine' do
      allow(@virtual_machine_manager.virtual_machine_lib).to receive(:create_update).and_return(nil)
      expect(@virtual_machine_manager.create_or_update_vm).to eq(nil)
    end
    it 'rescue exception while creating virtual machine' do
      allow(@virtual_machine_manager.virtual_machine_lib).to receive(:create_update)
                                                     .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @virtual_machine_manager.create_or_update_vm }.to raise_error('no backtrace')
    end
  end

  describe '# test delete virtual machine' do
    it 'raises AzureOperationError exception' do
      allow(@virtual_machine_manager.virtual_machine_lib).to receive(:get)
                                                                 .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @virtual_machine_manager.delete_vm }.to raise_error('no backtrace')

    end

    it 'raises a generic exception' do
      allow(@virtual_machine_manager.virtual_machine_lib).to receive(:get)
                                                                 .and_raise(MsRest::HttpOperationError.new('Error'))
      expect { @virtual_machine_manager.delete_vm }.to raise_error('no backtrace')
    end

    it 'returns virtual machine' do
      allow(@virtual_machine_manager.virtual_machine_lib).to receive(:get).and_return(@server)
      allow(@virtual_machine_manager.virtual_machine_lib).to receive(:delete).and_return(true)
      result = ['test-storage-account', @server.os_disk_vhd_uri, nil]
      expect(@virtual_machine_manager.delete_vm).to eq(result)
    end

    it 'checks for vm' do
      allow(@virtual_machine_manager.virtual_machine_lib).to receive(:get).and_return(nil)
      expect(@virtual_machine_manager.delete_vm).to eq(nil)
    end
  end
end

