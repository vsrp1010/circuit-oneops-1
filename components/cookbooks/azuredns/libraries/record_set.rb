# rubocop:disable MethodLength
# rubocop:disable AbcSize
# rubocop:disable ClassLength
# rubocop:disable LineLength
require ::File.expand_path('../../../azure_base/libraries/logger', __FILE__)


module AzureDns
  require 'chef'
  require 'rest-client'
  # Cookbook Name:: azuredns
  # Recipe:: set_dns_records
  #
  # This class handles following dns recordset operations
  # a) set dns recordset
  # b) get dns recordset
  # c) remove DNS recordset
  #
  class RecordSet
    attr_accessor :dns_client

    def initialize(platform_resource_group, dns_attributes)
      credentials = {
          tenant_id: dns_attributes[:tenant_id],
          client_secret: dns_attributes[:client_secret],
          client_id: dns_attributes[:client_id],
          subscription_id: dns_attributes[:subscription]
      }
      @dns_client = Fog::DNS::AzureRM.new(credentials)
      @zone = dns_attributes[:zone]
      @dns_resource_group = platform_resource_group
    end

    def get_existing_records_for_recordset(record_type, record_set_name)
      Chef::Log.info('AzureDns::RecordSet - Get existing records for RecordSet')

      begin
        record_set = @dns_client.record_sets.get(@dns_resource_group, record_set_name, @zone, record_type) if exists?(record_set_name, record_type)
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Exception setting #{record_type} records for the record set: #{record_set_name}...: #{e.body}")
      rescue => e
        OOLog.fatal("AzureDns::RecordSet - Exception is: #{e.message}")
      end
      if record_set.nil?
        Chef::Log.info('AzureDns::RecordSet - 404 code, record set does not exist. Returning empty array.')
        []
      else
        records = []
        if record_type == 'A'
          record_set.a_records.each do |record|
            records << record.ipv4address
          end
        elsif record_type == 'CNAME'
          record_set.cname_records.each do |record|
            records << record.cname
          end
        end

        records
      end
    end

    def set_records_on_record_set(record_set_name, records, record_type, ttl)
      Chef::Log.info('AzureDns::RecordSet - Create/Update RecordSet')
      begin
        @dns_client.record_sets.create(name: record_set_name,
                                       resource_group: @dns_resource_group,
                                       zone_name: @zone,
                                       records: records,
                                       type: record_type,
                                       ttl: ttl)

      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Exception setting #{record_type} records for the record set: #{record_set_name}...: #{e.body}")
      rescue => e
        OOLog.fatal("AzureDns::RecordSet - Exception is: #{e.message}")
      end
    end

    def remove_record_set(record_set_name, record_type)
      begin
        record_set = @dns_client.record_sets.get(@dns_resource_group, record_set_name, @zone, record_type)
        !record_set.nil? ? record_set.destroy : Chef::Log.info('AzureDns::RecordSet - 404 code, trying to delete something that is not there.')

      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Exception trying to remove #{record_type} records for the record set: #{record_set_name} ...: #{e.body}")
      rescue => e
        OOLog.fatal("AzureDns::RecordSet - Exception is: #{e.message}")
      end
    end

    def exists?(record_set_name, record_type)
      begin
        @dns_client.record_sets.check_record_set_exists(@dns_resource_group, record_set_name, @zone, record_type)
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("Exception trying to check #{record_set_name}")
      end
    end
  end
end
