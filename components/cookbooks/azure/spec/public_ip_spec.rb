require 'json'
require 'fog/azurerm'
require 'simplecov'
SimpleCov.start

require File.expand_path('../../libraries/public_ip.rb', __FILE__)
require ::File.expand_path('../../../azure_base/libraries/logger', __FILE__)
require ::File.expand_path('../../../azure_base/libraries/utils', __FILE__)

describe AzureNetwork::PublicIp do
  before :each do
    credentials = {
        tenant_id: '<TENANT_ID>',
        client_secret: '<CLIENT_SECRET>',
        client_id: '<CLIENT_ID>',
        subscription_id: '<SUBSCRIPTION>'
    }
    @platform_resource_group = '<RESOURCE-GROUP-NAME>'
    @public_ip_name = '<PUBLIC-IP-NAME>'
    @azure_client = AzureNetwork::PublicIp.new(credentials)
    @public_ip = Fog::Network::AzureRM::PublicIp.new
  end

  describe '# test build_public_ip_object functionality' do
    it 'builds desired object successfully' do
      expect(@azure_client.build_public_ip_object('public-ip')).to be_a Fog::Network::AzureRM::PublicIp
    end

    it 'checks output from given input in build desired object' do
      @public_ip.name = 'publicip-public-ip'
      expect(@azure_client.build_public_ip_object('public-ip')).to eq(@public_ip)
    end
  end

  describe '# test create_update functionality' do
    it 'creates successfully' do
      file_path = File.expand_path('public_ip_data.json', __dir__)
      file = File.open(file_path)
      pubip_response = file.read

      allow(@azure_client.network_client).to receive_message_chain(:public_ips, :create).and_return(pubip_response)
      expect(@azure_client.create_update(@platform_resource_group, @public_ip_name, @public_ip)).to_not eq(nil)
    end

    it 'raises AzureOperationError exception' do
      allow(@azure_client.network_client).to receive_message_chain(:public_ips, :create)
                                     .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @azure_client.create_update(@platform_resource_group, @public_ip_name, @public_ip)}.to raise_error('no backtrace')

    end

    it 'raises a generic exception' do
      allow(@azure_client.network_client).to receive_message_chain(:public_ips, :create)
                                     .and_raise(MsRest::HttpOperationError.new('Error'))
      expect { @azure_client.create_update(@platform_resource_group, @public_ip_name, @public_ip) }.to raise_error('no backtrace')
    end
  end

  describe '#test get functionality' do
    it 'successfull case of get functionality' do
      file_path = File.expand_path('public_ip_data.json', __dir__)
      file = File.open(file_path)
      pubip_response = file.read

      allow(@azure_client.network_client).to receive_message_chain(:public_ips, :get).and_return(pubip_response)
      expect(@azure_client.get(@platform_resource_group, @public_ip_name)).to_not eq(nil)
    end

    it 'raises AzureOperationError exception' do
      allow(@azure_client.network_client).to receive_message_chain(:public_ips, :get)
                                     .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @azure_client.get(@platform_resource_group, @public_ip_name)}.to raise_error('no backtrace')
    end

    it 'raises a generic exception' do
      allow(@azure_client.network_client).to receive_message_chain(:public_ips, :get)
                                     .and_raise(MsRest::HttpOperationError.new('Error'))
      expect { @azure_client.get(@platform_resource_group, @public_ip_name) }.to raise_error('no backtrace')
    end
  end

  describe '#test delete functionality' do
    it 'successfull case of delete functionality' do
      allow(@azure_client.network_client).to receive_message_chain(:public_ips, :get, :destroy).and_return(true)
      delete_pip = @azure_client.delete(@platform_resource_group, @public_ip_name)

      expect(delete_pip).to_not eq(false)
    end

    it 'raises AzureOperationError exception' do
      allow(@azure_client.network_client).to receive_message_chain(:public_ips, :get, :destroy)
                                           .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @azure_client.delete(@platform_resource_group, @public_ip_name) }.to raise_error('no backtrace')
    end

    it 'raises a generic exception' do
      allow(@azure_client.network_client).to receive_message_chain(:public_ips, :get, :destroy)
                                           .and_raise(MsRest::HttpOperationError.new('Error'))
      expect {  @azure_client.delete(@platform_resource_group, @public_ip_name) }.to raise_error('no backtrace')
    end
  end

  describe '#test check_existence_publicip functionality' do
    it 'successfull case of checking exist functionality' do
      allow(@azure_client.network_client).to receive_message_chain(:public_ips, :check_public_ip_exists).and_return(true)
      expect(@azure_client.check_existence_publicip(@platform_resource_group, @public_ip_name)).to eq(true)
    end

    it 'raises AzureOperationError exception' do
      allow(@azure_client.network_client).to receive_message_chain(:public_ips, :check_public_ip_exists)
                                     .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @azure_client.check_existence_publicip(@platform_resource_group, @public_ip_name)}.to raise_error('no backtrace')
    end

    it 'raises a generic exception' do
      allow(@azure_client.network_client).to receive_message_chain(:public_ips, :check_public_ip_exists)
                                     .and_raise(MsRest::HttpOperationError.new('Error'))
      expect { @azure_client.check_existence_publicip(@platform_resource_group, @public_ip_name) }.to raise_error('no backtrace')
    end
  end
end
