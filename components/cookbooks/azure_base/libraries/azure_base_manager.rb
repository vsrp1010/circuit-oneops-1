require File.expand_path('../../libraries/logger.rb', __FILE__)

module AzureBase
  # This is a base class that will handle grabbing information from the node
  # that all the recipes will use.
  # For specific parsing of the node, the subclasses will have to manage that.
  class AzureBaseManager

    attr_accessor :cloud_name,
                  :creds

    def initialize(node)
      @cloud_name = node[:workorder][:cloud][:ciName]

      OOLog.info("App Name is: #{node[:app_name]}")
      case node[:app_name]
      when /keypair|secgroup|compute|volume/
        service_name = 'compute'
      when /fqdn/
        service_name = 'dns'
      when /lb/
        service_name = 'lb'
      when /storage/
        service_name = 'storage'
      end

      OOLog.info("Service name is: #{service_name}")

      @service =
        node[:workorder][:services][service_name][@cloud_name][:ciAttributes]

      if @creds.nil?
        OOLog.info("Creds do NOT exist, creating...")
        @creds = {
            tenant_id: @service[:tenant_id],
            client_id: @service[:client_id],
            client_secret: @service[:client_secret],
            subscription_id: @service[:subscription]
        }
      else
        OOLog.info('Creds EXIST, no need to create.')
        puts 'Hell'
      end
    end
  end
end
