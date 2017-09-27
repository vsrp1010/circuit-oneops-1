require 'simplecov'
require 'rest-client'
SimpleCov.start
require File.expand_path('../../libraries/datadisk.rb', __FILE__)
require 'fog/azurerm'

describe Datadisk do
  before do
    creds = {
        tenant_id: 'TENANT_ID',
        client_id: 'CLIENT_ID',
        client_secret: 'CLIENT_SECRET',
        subscription_id: 'SUBSCRIPTION'
    }
    storage_account_name = 'Storage_account_name'
    rg_name_persistent_storage = 'RG_Name'
    instance_name = 'Test_Datadisk'
    @device_maps = ['Temp:RG_Name:storage_account_name:10:storage_account_name1']
    @datadisk = Datadisk.new(creds, storage_account_name, rg_name_persistent_storage, instance_name, @device_maps)
    @datadisk_response = Fog::Storage::AzureRM::DataDisk.new
    @vm_response = Fog::Compute::AzureRM::Server.new(
        name: 'fog-test-server',
        location: 'West US',
        resource_group: 'fog-test-rg',
        vm_size: 'Basic_A0',
        storage_account_name: 'shaffanstrg',
        username: 'shaffan',
        password: 'Confiz=123',
        disable_password_authentication: false,
        network_interface_card_id: '/subscriptions/########-####-####-####-############/resourceGroups/shaffanRG/providers/Microsoft.Network/networkInterfaces/testNIC',
        publisher: 'Canonical',
        offer: 'UbuntuServer',
        sku: '14.04.2-LTS',
        version: 'latest',
        platform: 'Windows',
        data_disks: [@datadisk_response]
    )
  end
  describe '#create' do
    it 'creates datadisk successfully' do
      allow(@datadisk).to receive(:check_blob_exist).and_return(false)
      allow(@datadisk.storage_client).to receive(:create_disk).and_return(true)
      expect(@datadisk.create).to eq(@device_maps)
    end
    it 'raises error if datadisk already exist' do
      allow(@datadisk).to receive(:check_blob_exist).and_return(true)
      expect { @datadisk.create }.to raise_error('no backtrace')
    end
    it 'raises AzureOperationError exception while creating datadisk' do
      exception = MsRestAzure::AzureOperationError.new('Errors')
      allow(@datadisk).to receive(:check_blob_exist).and_return(false)
      allow(@datadisk.storage_client).to receive(:create_disk)
        .and_raise(exception)
      expect { @datadisk.create }.to raise_error('no backtrace')
    end
  end

  describe '#attach' do
    it 'attach datadisks to a VM successfully' do
      allow(@datadisk.virtual_machine_lib).to receive(:get).and_return(@vm_response)
      allow(@vm_response).to receive(:attach_data_disk).and_return(true)
      expect(@datadisk.attach).to eq('storage_account_name1')
    end
    it 'attach datadisks to a VM if flag is true' do
      custom_vm = @vm_response
      custom_vm.data_disks[0].lun = 0
      allow(@datadisk.virtual_machine_lib).to receive(:get).and_return(@vm_response)
      allow(@vm_response).to receive(:attach_data_disk).and_return(true)
      expect(@datadisk.attach).to eq('storage_account_name1')
    end
  end


  describe '#check_blob_exist' do
    it 'Checks if blob exist or not' do
      blob = double
      allow(@datadisk.storage_client).to receive(:get_blob_properties).and_return(blob)
      expect(@datadisk.check_blob_exist('page_blob')).to eq(true)
    end
    it 'Checks if blob exist or not' do
      allow(@datadisk.storage_client).to receive(:get_blob_properties)
        .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect(@datadisk.check_blob_exist('page_blob')).to eq(false)
    end
  end

  describe '#get_storage_access_key' do
    it 'get storage access keys successfully' do
      key1 = double
      key2 = double
      allow(key2).to receive(:key_name) { 'key2' }
      allow(key2).to receive(:value) { 'xyz123mno' }
      keys = [key1, key2]
      allow(@datadisk.storage_client).to receive(:get_storage_access_keys).and_return(keys)
      expect(@datadisk.get_storage_access_key).to eq('xyz123mno')
    end
    it 'raises exception while getting storage access key' do
      allow(@datadisk.storage_client).to receive(:get_storage_access_keys)
        .and_raise(MsRest::HttpOperationError.new('Error'))
      expect { @datadisk.get_storage_access_key }.to raise_error('no backtrace')
    end
    it 'raises AzureOperationError exception while getting storage access key' do
      allow(@datadisk.storage_client).to receive(:get_storage_access_keys)
        .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @datadisk.get_storage_access_key }.to raise_error('no backtrace')
    end
  end

  describe '#delete_datadisk' do
    it 'delete datadisk successfully' do
      allow(@datadisk).to receive(:delete_disk_by_name).and_return('success')
      expect(@datadisk.delete_datadisk).to eq(true)
    end
    it 'delete datadisk after detaching it if its under lease' do
      allow(@datadisk).to receive(:delete_disk_by_name).and_return('DiskUnderLease')
      allow(@datadisk).to receive(:detach).and_return(true)
      expect(@datadisk.delete_datadisk).to eq(true)
    end
  end

  describe '#delete_disk_by_name' do
    it 'return failure if it is unable to delete datadisk' do
      allow(@datadisk.storage_client).to receive(:delete_blob).and_return(nil)
      expect(@datadisk.delete_disk_by_name('Blob_Name')).to eq('failure')
    end
    it 'delete datadisk by name successfully' do
      allow(@datadisk.storage_client).to receive(:delete_blob).and_return(true)
      expect(@datadisk.delete_disk_by_name('Blob_Name')).to eq('success')
    end
    it 'raises AzureOperationError exception while deleting datadisk by name' do
      exception = MsRestAzure::AzureOperationError.new('Errors')
      allow(exception).to receive(:type) { 'InvalidParameter' }
      allow(@datadisk.storage_client).to receive(:delete_blob)
        .and_raise(exception)
      expect { @datadisk.delete_disk_by_name('Blob_Name') }.to raise_error('no backtrace')
    end
    it 'return DiskUnderLease if error type in LeaseIdMissing' do
      exception = MsRestAzure::AzureOperationError.new('Errors')
      allow(exception).to receive(:type) { 'LeaseIdMissing' }
      allow(@datadisk.storage_client).to receive(:delete_blob)
        .and_raise(exception)
      expect(@datadisk.delete_disk_by_name('Blob_Name')).to eq('DiskUnderLease')
    end
    it 'raises exception while deleting datadisk by name' do
      allow(@datadisk.storage_client).to receive(:delete_blob)
        .and_raise(MsRest::HttpOperationError.new('Error'))
      expect { @datadisk.delete_disk_by_name('Blob_Name') }.to raise_error('no backtrace')
    end
  end

  describe '#detach' do
    it 'detach datadisk successfully' do
      allow(@datadisk.virtual_machine_lib).to receive(:get).and_return(@vm_response)
      allow(@vm_response).to receive(:detach_data_disk).and_return(true)
      expect(@datadisk.detach).to eq(@device_maps)
    end
    it 'delete datadisk if diskname is storage_account_name-datadisk-storage_account_name1' do
      custom_vm = @vm_response
      custom_vm.data_disks[0].name = 'storage_account_name-datadisk-storage_account_name1'
      allow(@datadisk.virtual_machine_lib).to receive(:get).and_return(custom_vm)
      allow(custom_vm).to receive(:detach_data_disk).and_return(true)
      expect(@datadisk.detach).to eq(@device_maps)
    end
  end
end
