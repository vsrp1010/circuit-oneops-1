require 'json'
require 'fog/azurerm'

require 'simplecov'
SimpleCov.start


require File.expand_path('../../libraries/zone.rb', __FILE__)
require ::File.expand_path('../../../azure_base/libraries/logger', __FILE__)

describe AzureDns::Zone do
  before :each do
    credentials = {
      'tenant_id': '<TENANT_ID>',
      'client_id': '<CLIENT_ID>',
      'client_secret': '<CLIENT_SECRET>',
      'subscription': '<SUBSCRIPTION_ID>',
      'zone': '<ZONE-NAME>'
    }
    platform_resource_group = '<RESOURCE-GROUP-NAME>'


    @zone = AzureDns::Zone.new(credentials, platform_resource_group)
  end

  describe '# test create functionality' do
    it 'creates zone successfully' do
      file_path = File.expand_path('zone_data.json', __dir__)
      file = File.open(file_path)
      zone_response = file.read

      allow(@zone.dns_client).to receive_message_chain(:zones, :create).and_return(zone_response)
      expect(@zone.create).to_not eq(nil)
    end

    it 'raises AzureOperationError exception while creating zone' do
      allow(@zone.dns_client).to receive_message_chain(:zones, :create)
                                     .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @zone.create}.to raise_error('no backtrace')
    end

    it 'raises exception while creating zone' do
      allow(@zone.dns_client).to receive_message_chain(:zones, :create)
                                     .and_raise(MsRest::HttpOperationError.new('Error'))
      expect { @zone.create }.to raise_error('no backtrace')
    end

  end

  describe '#check_for_zone' do
    it 'varifies that zone exists' do
      allow(@zone.dns_client).to receive_message_chain(:zones, :check_zone_exists?).and_return(true)
      expect(@zone.check_for_zone).to eq(true)
    end

    it 'varifies that zone does not exist' do
      allow(@zone.dns_client).to receive_message_chain(:zones, :check_zone_exists?)
                                     .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @zone.check_for_zone}.to raise_error('no backtrace')
    end

    it 'varifies that status code other than causes exception' do
      allow(@zone.dns_client).to receive_message_chain(:zones, :check_zone_exists?)
                                     .and_raise(MsRest::HttpOperationError.new('Error'))
      expect { @zone.check_for_zone }.not_to raise_error('no backtrace')
    end
  end
end
