require 'simplecov'
SimpleCov.start
require File.expand_path('../../libraries/traffic_managers.rb', __FILE__)
require File.expand_path('../../libraries/model/traffic_manager.rb', __FILE__)
require File.expand_path('../../libraries/model/dns_config.rb', __FILE__)
require File.expand_path('../../libraries/model/monitor_config.rb', __FILE__)
require File.expand_path('../../libraries/model/endpoint.rb', __FILE__)
require 'fog/azurerm'

describe TrafficManagers do
  before do
    dns_attributes = {
      tenant_id: '<TENANT_ID>',
      client_id: 'CLIENT_ID',
      client_secret: 'CLIENT_SECRET',
      subscription_id: 'SUBSCRIPTION_ID'
    }
    resource_group_name = '<RG_NAME>'
    profile_name = '<PROFILE_NAME>'
    @traffic_manager = TrafficManagers.new(resource_group_name, profile_name, dns_attributes)
    @traffic_manager_response = Fog::TrafficManager::AzureRM::TrafficManagerProfile.new(
      name: 'fog-test-profile',
      resource_group: 'fog-test-rg',
      traffic_routing_method: 'Performance',
      relative_name: 'fog-test-app',
      ttl: '30',
      protocol: 'http',
      port: '80',
      path: '/monitorpage.aspx'
    )
  end

  describe '#create_update_profile' do
    monitor_config = MonitorConfig.new('http', 80, '/')
    dns_config = DnsConfig.new('relative_dns_name', 300)
    endpoint = EndPoint.new('endpoint_name', 'target', 'eastus')
    endpoint.set_endpoint_status(200)
    endpoint.set_weight(20)
    endpoint.set_priority(1)
    traffic_manager_obj = TrafficManager.new('Performance', dns_config, monitor_config, [endpoint])
    traffic_manager_obj.set_profile_status = 'Enable'
    it 'creates/updates traffic manager profile successfully' do
      allow(@traffic_manager.traffic_manager_service).to receive_message_chain(:traffic_manager_profiles, :create)
        .and_return(@traffic_manager_response)

      expect(@traffic_manager.create_update_profile(traffic_manager_obj)).to eq(@traffic_manager_response)
    end
    it 'raises exception while creating/updating traffic manager profile' do
      allow(@traffic_manager.traffic_manager_service).to receive_message_chain(:traffic_manager_profiles, :create)
        .and_raise(MsRestAzure::AzureOperationError.new('Errors'))

      expect { @traffic_manager.create_update_profile(traffic_manager_obj) }.to raise_error('no backtrace')
    end
  end

  describe '#delete_profile' do
    it 'deletes traffic manager profile successfully' do
      allow(@traffic_manager.traffic_manager_service).to receive_message_chain(:traffic_manager_profiles, :get, :destroy).and_return(true)

      expect(@traffic_manager.delete_profile).to eq(true)
    end
    it 'raises AzureOperationError exception' do
      allow(@traffic_manager.traffic_manager_service).to receive_message_chain(:traffic_manager_profiles, :get, :destroy)
        .and_raise(MsRestAzure::AzureOperationError.new('Errors'))

      expect { @traffic_manager.delete_profile }.to raise_error('no backtrace')
    end
    it 'raises exception while deleting traffic manager profile' do
      allow(@traffic_manager.traffic_manager_service).to receive_message_chain(:traffic_manager_profiles, :get, :destroy)
        .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @traffic_manager.delete_profile }.to raise_error('no backtrace')
    end
  end

  describe '#get_profile' do
    it 'gets traffic manager profile successfully' do
      allow(@traffic_manager.traffic_manager_service).to receive_message_chain(:traffic_manager_profiles, :get).and_return(@traffic_manager_response)
      expect(@traffic_manager.get_profile).to_not eq(nil)
    end
    it 'returns nil while getting traffic manager profile if exception is ResourceNotFound' do
      allow(@traffic_manager.traffic_manager_service).to receive_message_chain(:traffic_manager_profiles, :get)
        .and_raise(MsRestAzure::AzureOperationError.new('Errors'))

      expect(@traffic_manager.get_profile).to eq(nil)
    end
  end

  describe '#initialize_traffic_manager' do
    it 'initializes traffic manager successfully' do
      dns_attributes = {
          tenant_id: '<TENANT_ID>',
          client_id: '<CLIENT_ID>',
          client_secret: '<CLIENT_SECRET>',
          subscription: '<SUBSCRIPTION_ID>',
          zone: 'dnszone.com'
      }
      resource_group_names = ['<RG_NAME>']
      ns_path_parts = %w(confiz first-try env bom first-plt 1)
      gdns_attributes = {
          'ttl': '30',
          'traffic_routing_method': 'Performance'
      }
      listeners = 'http [80]'
      subdomain = 'en.first-try.Confiz'

      allow(@traffic_manager).to receive(:get_public_ip_fqdns).and_return(['test.test.test.test'])
      traffic_manager = @traffic_manager.initialize_traffic_manager(dns_attributes,resource_group_names,ns_path_parts, gdns_attributes, listeners, subdomain)
      expect(traffic_manager.routing_method).to eq('Performance')
      expect(traffic_manager.dns_config.ttl).to eq('30')
      expect(traffic_manager.monitor_config.protocol).to eq('HTTP')
      expect(traffic_manager.monitor_config.port).to eq('80')
      expect(traffic_manager.monitor_config.path).to eq('/')
      expect(traffic_manager.endpoints[0].name).to eq('endpoint_test_0')
      expect(traffic_manager.profile_status).to eq('Enabled')
      expect(traffic_manager.location).to eq('global')
    end
  end
end
