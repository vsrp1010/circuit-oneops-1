require 'json'
require 'fog/azurerm'
require 'simplecov'
SimpleCov.start

require File.expand_path('../../libraries/subnet', __FILE__)
require ::File.expand_path('../../../azure_base/libraries/logger', __FILE__)
require ::File.expand_path('../../../azure_base/libraries/utils', __FILE__)

describe AzureNetwork::Subnet do
  before :each do
    credentials = {
        tenant_id: '<TENANT_ID>',
        client_secret: '<CLIENT_SECRET>',
        client_id: '<CLIENT_ID>',
        subscription_id: '<SUBSCRIPTION>'
    }
    @azure_client = AzureNetwork::Subnet.new(credentials)
    @azure_client.sub_address = ['10.12.15.19', '10.12.15.19']
    @azure_client.name = 'subnet-name'
  end

  describe '# test build_subnet_object functionality' do
    it 'builds desired object successfully' do
      expect(@azure_client.build_subnet_object).to be_a Array
    end
  end

  describe '# test get_subnet_with_available_ips functionality' do
    it 'builds desired object successfully with express_route enabled' do
      subnet1 = Fog::Network::AzureRM::Subnet.new
      subnet1.name = 'gatewaysubnet'
      subnet1.address_prefix = '19.16.14.16/32'

      subnet2 = Fog::Network::AzureRM::Subnet.new
      subnet2.name = 'gatewaysubnet1'
      subnet2.address_prefix = '19.16.14.16/16'

      expect(@azure_client.get_subnet_with_available_ips([subnet1, subnet2], 'true')).to be_a Fog::Network::AzureRM::Subnet
    end

    it 'builds desired object successfully with express_route disabled' do
      subnet1 = Fog::Network::AzureRM::Subnet.new
      subnet1.name = 'gatewaysubnet'
      subnet1.address_prefix = '19.16.14.16/32'

      subnet2 = Fog::Network::AzureRM::Subnet.new
      subnet2.name = 'gatewaysubnet1'
      subnet2.address_prefix = '19.16.14.16/16'

      expect(@azure_client.get_subnet_with_available_ips([subnet1, subnet2], 'false')).to be_a Fog::Network::AzureRM::Subnet
    end

    it 'builds desired object successfully with no subnet' do
      subnet2 = Fog::Network::AzureRM::Subnet.new
      subnet2.name = 'gatewaysubnet1'
      subnet2.ip_configurations_ids = ['id-1', 'id-3','id-1', 'id-3','id-1', 'id-3','id-1', 'id-3','id-1','id-1','id-1','id-1','id-1','id-1']
      subnet2.address_prefix = '15.0.0.0/28'

      expect(@azure_client.get_subnet_with_available_ips([subnet2], 'false')).not_to eq(nil)
    end
  end

  describe '# test list functionality' do
    it 'creates successfully' do
      file_path = File.expand_path('subnet_data.json', __dir__)
      file = File.open(file_path)
      subnet_response = file.read

      allow(@azure_client.network_client).to receive_message_chain(:subnets).and_return(subnet_response)
      expect(@azure_client.list(@platform_resource_group, 'vnet_name')).to_not eq(nil)
    end

    it 'raises AzureOperationError exception' do
      allow(@azure_client.network_client).to receive_message_chain(:subnets)
                                                 .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @azure_client.list(@platform_resource_group, 'vnet_name')}.to raise_error('no backtrace')

    end

    it 'raises a generic exception' do
      allow(@azure_client.network_client).to receive_message_chain(:subnets)
                                                 .and_raise(MsRest::HttpOperationError.new('Error'))
      expect { @azure_client.list(@platform_resource_group, 'vnet_name') }.to raise_error('no backtrace')
    end
  end

  describe '#test get functionality' do
    it 'successfull case of get functionality' do
      file_path = File.expand_path('subnet_data.json', __dir__)
      file = File.open(file_path)
      subnet_response = file.read

      allow(@azure_client.network_client).to receive_message_chain(:subnets, :get).and_return(subnet_response)
      expect(@azure_client.get(@platform_resource_group, 'vnet_name', 'subnet_name')).to_not eq(nil)
    end

    it 'raises AzureOperationError exception' do
      allow(@azure_client.network_client).to receive_message_chain(:subnets, :get)
                                                 .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @azure_client.get(@platform_resource_group, 'vnet_name', 'subnet_name')}.to raise_error('no backtrace')
    end

    it 'raises a generic exception' do
      allow(@azure_client.network_client).to receive_message_chain(:subnets, :get)
                                                 .and_raise(MsRest::HttpOperationError.new('Error'))
      expect { @azure_client.get(@platform_resource_group, 'vnet_name', 'subnet_name') }.to raise_error('no backtrace')
    end
  end

end
