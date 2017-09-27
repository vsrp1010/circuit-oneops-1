# rubocop:disable LineLength

require 'json'
require 'rest-client'

require 'simplecov'
SimpleCov.start

require File.expand_path('../../libraries/record_set.rb', __FILE__)
require ::File.expand_path('../../../azure_base/libraries/logger', __FILE__)

describe AzureDns::RecordSet do
  before do
    platform_resource_group = 'azure_resource_group'
    dns_attributes = {
      'tenant_id': '<TENANT_ID>',
      'client_id': '<CLIENT_ID>',
      'client_secret': '<CLIENT_SECRET>',
      'subscription': '<SUBSCRIPTION_ID>',
      'zone': '<ZONE-NAME>'
    }
    @record_set = AzureDns::RecordSet.new(platform_resource_group, dns_attributes)
  end

  #
  # Testing Get Records on RecordSet
  #

  describe '#get_existing_records_for_recordset' do
    it 'returns A type or CNAME record for recordset' do
      file_path = File.expand_path('A_type_record_data.json', __dir__)
      file = File.open(file_path)
      dns_response = file.read

      allow(@record_set.dns_client).to receive_message_chain(:record_sets, :get).and_return(dns_response)
      expect(@record_set.get_existing_records_for_recordset('A', 'RS_Name')).to_not eq(nil)
    end

    it 'raises AzureOperationError exception' do
      allow(@record_set.dns_client).to receive_message_chain(:record_sets, :get)
                                           .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @record_set.get_existing_records_for_recordset('A', 'RS_Name') }.to raise_error('no backtrace')
    end

    it 'raises an exception' do
      allow(@record_set.dns_client).to receive_message_chain(:record_sets, :get)
                                           .and_raise(MsRest::HttpOperationError.new('Error'))
      expect { @record_set.get_existing_records_for_recordset('A', 'RS_Name')}.to raise_error('no backtrace')
    end

  end

  #
  # Testing Set Records on RecordSet
  #

  describe '#Testing set_records_on_record_set functionality' do
    it 'sets A type records on recordset' do
      file_path = File.expand_path('record_set_data.json', __dir__)
      file = File.open(file_path)
      record_set_response = file.read
      records = ['contoso.com']

      allow(@record_set.dns_client).to receive_message_chain(:record_sets, :create).and_return(record_set_response)
      expect(@record_set.set_records_on_record_set('RS_Name', records, 'A', 300)).to_not eq(nil)
    end

    it 'raises AzureOperationError exception' do
      records = ['contoso.com']
      allow(@record_set.dns_client).to receive_message_chain(:record_sets, :create)
                                     .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @record_set.set_records_on_record_set('RS', records, 'CNAME', 300) }.to raise_error('no backtrace')

    end

    it 'raises an exception' do
      records = ['contoso.com']
      allow(@record_set.dns_client).to receive_message_chain(:record_sets, :create)
                                     .and_raise(MsRest::HttpOperationError.new('Error'))
      expect { @record_set.set_records_on_record_set('RS', records, 'CNAME', 300) }.to raise_error('no backtrace')
    end
  end


  #
  # Testing Remove RecordSet
  #

  describe '# It tests remove_record_set functionality' do
    it 'removes recordset' do
      allow(@record_set.dns_client).to receive_message_chain(:record_sets, :get, :destroy).and_return(true)
      delete_rs = @record_set.remove_record_set('Recordset_Name', 'A')

      expect(delete_rs).to_not eq(false)
    end

    it 'raises AzureOperationError exception' do
      allow(@record_set.dns_client).to receive_message_chain(:record_sets, :get, :destroy)
                                                 .and_raise(MsRestAzure::AzureOperationError.new('Errors'))

      expect { @record_set.remove_record_set('Recordset_Name', 'A') }.to raise_error('no backtrace')
    end

    it 'raises an exception' do
      allow(@record_set.dns_client).to receive_message_chain(:record_sets, :get, :destroy)
                                                 .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @record_set.remove_record_set('Recordset_Name', 'A') }.to raise_error('no backtrace')
    end
  end
end
