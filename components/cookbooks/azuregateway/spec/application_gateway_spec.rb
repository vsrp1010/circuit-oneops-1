require 'simplecov'
require 'rest-client'
SimpleCov.start
require File.expand_path('../../libraries/application_gateway.rb', __FILE__)
require 'fog/azurerm'

describe AzureNetwork::Gateway do
  before do
    credentials = {
      tenant_id: '<TENANT_ID>',
      client_id: 'CLIENT_ID',
      client_secret: 'CLIENT_SECRET',
      subscription_id: 'SUBSCRIPTION_ID'
    }
    resource_group_name = '<RG_NAME>'
    ag_name = '<AG_NAME>'

    @gateway = AzureNetwork::Gateway.new(resource_group_name, ag_name, credentials)
    @gateway_response = Fog::ApplicationGateway::AzureRM::Gateway.new(
      name: 'gateway',
      location: 'eastus',
      resource_group: 'fogRM-rg'
    )
  end

  describe '#set_gateway_configuration' do
    it 'checks gateway configuration object name' do
      subnet = double
      allow(subnet).to receive(:id) { 'SUBNET_ID' }
      @gateway.set_gateway_configuration(subnet)

      expect(@gateway.gateway_attributes[:gateway_configuration]).to_not eq(nil)
    end
  end

  describe '#set_backend_address_pool' do
    it 'checks backend pool object name' do
      backend_address_list = ['10.0.2.5/24']
      @gateway.set_backend_address_pool(backend_address_list)

      expect(@gateway.gateway_attributes[:backend_address_pool]).to_not eq(nil)
    end
  end

  describe '#set_https_settings' do
    it 'varify if cookies are enabled in https settings' do
      @gateway.set_https_settings
      http_settings = @gateway.gateway_attributes[:https_settings]

      expect(http_settings).to_not eq(nil)
      expect(http_settings[:name]).to eq('gateway_settings')
      expect(http_settings[:cookie_based_affinity]).to eq('Enabled')
    end
    it 'varify if cookies are disabled in https settings' do
      @gateway.set_https_settings(false)
      http_settings = @gateway.gateway_attributes[:https_settings]

      expect(http_settings).to_not eq(nil)
      expect(http_settings[:cookie_based_affinity]).to eq('Disabled')
    end
  end

  describe '#set_gateway_port' do
    it 'verify application gateway front port is 443 if ssl certificate exists' do
      @gateway.set_gateway_port(true)
      gateway_frontend_port = @gateway.gateway_attributes[:gateway_port]

      expect(gateway_frontend_port).to_not eq(nil)
      expect(gateway_frontend_port[:name]).to eq('gateway_front_port')
      expect(gateway_frontend_port[:port]).to eq(443)
    end
    it 'verify if application gateway front port is 80 if ssl certificate does not exist' do
      @gateway.set_gateway_port(false)
      gateway_frontend_port = @gateway.gateway_attributes[:gateway_port]

      expect(gateway_frontend_port).to_not eq(nil)
      expect(gateway_frontend_port[:port]).to eq(80)
    end
  end

  describe '#set_frontend_ip_config' do
    it 'sets the subnet for frontend ip configurations if public IP is nil' do
      public_ip = nil
      subnet = double
      allow(subnet).to receive(:id) { 'SUBNET_ID' }
      @gateway.set_frontend_ip_config(public_ip, subnet)
      frontend_ip_config = @gateway.gateway_attributes[:frontend_ip_config]

      expect(frontend_ip_config).to_not eq(nil)
      expect(frontend_ip_config[:name]).to eq('frontend_ip_config')
      expect(frontend_ip_config[:private_ip_allocation_method]).to eq('Dynamic')
      expect(frontend_ip_config[:subnet_id]).to_not eq(nil)
    end
    it 'sets the public IP for frontend ip configurations if public IP is not nil' do
      public_ip = double
      subnet = nil
      allow(public_ip).to receive(:id) { 'PUBLIC_IP_ID' }
      @gateway.set_frontend_ip_config(public_ip, subnet)
      frontend_ip_config = @gateway.gateway_attributes[:frontend_ip_config]

      expect(frontend_ip_config).to_not eq(nil)
      expect(frontend_ip_config[:public_ip_address_id]).to_not eq(nil)
    end
  end

  describe '#set_ssl_certificate' do
    it 'checks attribute values of ssl certificate object' do
      data = 'DATA'
      password = 'PASSWORD'
      @gateway.set_ssl_certificate(data, password)
      ssl_certificate = @gateway.gateway_attributes[:ssl_certificate]

      expect(ssl_certificate).to_not eq(nil)
      expect(ssl_certificate[:name]).to eq('ssl_certificate')
      expect(ssl_certificate[:data]).to eq(data)
      expect(ssl_certificate[:password]).to eq(password)
    end
  end

  describe '#set_listener' do
    it 'returns application gateway listener properties with HTTPS protocol' do
      subnet = double
      public_ip = nil
      allow(subnet).to receive(:id) { 'SUBNET_ID' }
      @gateway.set_frontend_ip_config(public_ip, subnet)
      @gateway.set_gateway_port(true)
      @gateway.set_listener(true)
      listener = @gateway.gateway_attributes[:listener]

      expect(listener).to_not eq(nil)
      expect(listener[:name]).to eq('gateway_listener')
      expect(listener[:protocol]).to eq('Https')
    end
    it 'returns application gateway listener properties with HTTP protocol' do
      subnet = double
      public_ip = nil
      allow(subnet).to receive(:id) { 'SUBNET_ID' }
      @gateway.set_frontend_ip_config(public_ip, subnet)
      @gateway.set_gateway_port(true)
      @gateway.set_listener(false)
      listener = @gateway.gateway_attributes[:listener]

      expect(listener).to_not eq(nil)
      expect(listener[:name]).to eq('gateway_listener')
      expect(listener[:protocol]).to eq('Http')
    end
  end

  describe '#set_gateway_request_routing_rule' do
    it 'checks gateway request routing rule name' do
      subnet = double
      public_ip = nil
      backend_address_list = ['10.0.2.5/24']
      @gateway.set_backend_address_pool(backend_address_list)
      allow(subnet).to receive(:id) { 'SUBNET_ID' }
      @gateway.set_frontend_ip_config(public_ip, subnet)
      @gateway.set_gateway_port(true)
      @gateway.set_listener(true)
      @gateway.set_https_settings
      @gateway.set_gateway_request_routing_rule
      routing_rule = @gateway.gateway_attributes[:gateway_request_routing_rule]

      expect(routing_rule).to_not eq(nil)
      expect(routing_rule[:name]).to eq('gateway_request_route_rule')
    end
  end

  describe '#set_gateway_sku' do
    it 'returns gateway sku object having sku name small' do
      sku_name = 'small'
      @gateway.set_gateway_sku(sku_name)
      gateway_sku = @gateway.gateway_attributes[:gateway_sku_name]

      expect(gateway_sku).to_not eq(nil)
      expect(gateway_sku).to eq('Standard_Small')
    end
    it 'returns gateway sku object having sku name medium' do
      sku_name = 'medium'
      @gateway.set_gateway_sku(sku_name)
      gateway_sku = @gateway.gateway_attributes[:gateway_sku_name]

      expect(gateway_sku).to_not eq(nil)
      expect(gateway_sku).to eq('Standard_Medium')
    end
    it 'returns gateway sku object having sku name large' do
      sku_name = 'large'
      @gateway.set_gateway_sku(sku_name)
      gateway_sku = @gateway.gateway_attributes[:gateway_sku_name]

      expect(gateway_sku).to_not eq(nil)
      expect(gateway_sku).to eq('Standard_Large')
    end
    it 'returns gateway sku object having sku name medium' do
      sku_name = 'ANY_OTHER'
      @gateway.set_gateway_sku(sku_name)
      gateway_sku = @gateway.gateway_attributes[:gateway_sku_name]

      expect(gateway_sku).to_not eq(nil)
      expect(gateway_sku).to eq('Standard_Medium')
    end
  end

  describe '#create_or_update' do
    it 'creates application gateway successfully' do
      allow(@gateway.application_gateway).to receive_message_chain(:gateways, :create).and_return(@gateway_response)
      expect(@gateway.create_or_update('east-us', false)).to_not eq(nil)
    end
    it 'raises AzureOperationError exception while creating application gateway' do
      allow(@gateway.application_gateway).to receive_message_chain(:gateways, :create)
        .and_raise(MsRestAzure::AzureOperationError.new('Errors'))

      expect { @gateway.create_or_update('east-us', true) }.to raise_error('no backtrace')
    end
    it 'raises exception while creating application gateway' do
      allow(@gateway.application_gateway).to receive_message_chain(:gateways, :create)
        .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @gateway.create_or_update('east-us', true) }.to raise_error('no backtrace')
    end
  end

  describe '#delete' do
    it 'deletes application gateway successfully' do
      allow(@gateway.application_gateway).to receive_message_chain(:gateways, :get, :destroy).and_return(true)
      delete_gw = @gateway.delete

      expect(delete_gw).to_not eq(false)
    end
    it 'raises AzureOperationError exception' do
      allow(@gateway.application_gateway).to receive_message_chain(:gateways, :get, :destroy)
        .and_raise(MsRestAzure::AzureOperationError.new('Errors'))

      expect { @gateway.delete }.to raise_error('no backtrace')
    end
    it 'raises exception while deleting application gateway' do
      allow(@gateway.application_gateway).to receive_message_chain(:gateways, :get, :destroy)
        .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @gateway.delete }.to raise_error('no backtrace')
    end
  end
end
