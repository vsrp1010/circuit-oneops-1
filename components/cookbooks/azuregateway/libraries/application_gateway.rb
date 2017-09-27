require 'fog/azurerm'
require 'chef'
require 'yaml'
require File.expand_path('../../../azure_base/libraries/logger.rb', __FILE__)

module AzureNetwork
  # Cookbook Name:: azuregateway
  class Gateway
    attr_accessor :gateway_attributes
    attr_accessor :application_gateway
    def initialize(resource_group_name, ag_name, creds)
      @subscription_id = creds[:subscription_id]
      @resource_group_name = resource_group_name
      @ag_name = ag_name
      @application_gateway = Fog::ApplicationGateway::AzureRM.new(creds)
      @gateway_attributes = {}
      @configurations = YAML.load_file(File.expand_path('../config/config.yml', __dir__))
    end

    def get_attribute_id(gateway_attribute, attribute_name)
      @configurations['gateway']['subscription_id'] % { subscription_id: @subscription_id, resource_group_name: @resource_group_name, ag_name: @ag_name, gateway_attribute: gateway_attribute, attribute_name: attribute_name }
    end

    def set_gateway_configuration(subnet)
      gateway_configuration = {
        name: @configurations['gateway']['gateway_config_name'],
        subnet_id: subnet.id
      }

      @gateway_attributes[:gateway_configuration] = gateway_configuration
    end

    def set_backend_address_pool(backend_address_list)
      gateway_backend_pool = {}
      backend_addresses = []
      backend_address_list.each do |backend_address|
        backend_addr = {}
        backend_addr[:ipAddress] = backend_address
        backend_addresses.push(backend_addr)
      end

      gateway_backend_pool[:name] = @configurations['gateway']['backend_address_pool_name']
      gateway_backend_pool[:id] = get_attribute_id('backendAddressPools', gateway_backend_pool[:name])
      gateway_backend_pool[:ip_addresses] = backend_addresses

      @gateway_attributes[:backend_address_pool] = gateway_backend_pool
    end

    def set_https_settings(enable_cookie = true)
      https_settings = {
        name: @configurations['gateway']['http_settings_name'],
        id: get_attribute_id('backendHttpSettingsCollection', @configurations['gateway']['http_settings_name']),
        port: 80,
        protocol: 'Http',
        cookie_based_affinity: enable_cookie ? 'Enabled' : 'Disabled'
      }

      @gateway_attributes[:https_settings] = https_settings
    end

    def set_gateway_port(ssl_certificate_exist)
      gateway_port = {
        name: @configurations['gateway']['gateway_front_port_name'],
        id: get_attribute_id('frontendPorts', @configurations['gateway']['gateway_front_port_name']),
        port: ssl_certificate_exist ? 443 : 80
      }

      @gateway_attributes[:gateway_port] = gateway_port
    end

    def set_frontend_ip_config(public_ip, subnet)
      frontend_ip_config = {}
      frontend_ip_config[:name] = @configurations['gateway']['frontend_ip_config_name']
      frontend_ip_config[:id] = get_attribute_id('frontendIPConfigurations', frontend_ip_config[:name])
      if public_ip.nil?
        frontend_ip_config[:subnet_id] = subnet.id
        frontend_ip_config[:private_ip_allocation_method] = 'Dynamic'
      else
        frontend_ip_config[:public_ip_address_id] = public_ip.id
      end

      @gateway_attributes[:frontend_ip_config] = frontend_ip_config
    end

    def set_ssl_certificate(data, password)
      ssl_certificate = {
        name: @configurations['gateway']['ssl_certificate_name'],
        id: get_attribute_id('sslCertificates', @configurations['gateway']['ssl_certificate_name']),
        data: data,
        password: password
      }

      @gateway_attributes[:ssl_certificate] = ssl_certificate
    end

    def set_listener(certificate_exist)
      listener = {
        name: @configurations['gateway']['gateway_listener_name'],
        id: get_attribute_id('httpListeners', @configurations['gateway']['gateway_listener_name']),
        protocol: certificate_exist ? 'Https' : 'Http',
        frontend_ip_config_id: @gateway_attributes[:frontend_ip_config][:id],
        frontend_port_id: @gateway_attributes[:gateway_port][:id],
        ssl_certificate: @gateway_attributes[:ssl_certificate]
      }

      @gateway_attributes[:listener] = listener
    end

    def set_gateway_request_routing_rule
      gateway_request_routing_rule = {
        name: @configurations['gateway']['gateway_request_route_rule_name'],
        type: 'Basic',
        backend_http_settings_id: @gateway_attributes[:https_settings][:id],
        http_listener_id: @gateway_attributes[:listener][:id],
        backend_address_pool_id: @gateway_attributes[:backend_address_pool][:id]
      }

      @gateway_attributes[:gateway_request_routing_rule] = gateway_request_routing_rule
    end

    def set_gateway_sku(sku_name)
      gateway_sku_name = case sku_name.downcase
                         when 'small'
                           'Standard_Small'
                         when 'medium'
                           'Standard_Medium'
                         when 'large'
                           'Standard_Large'
                         else
                           'Standard_Medium'
                         end

      @gateway_attributes[:gateway_sku_name] = gateway_sku_name
    end

    def create_or_update(location, certificate_exist)
      begin
        ssl_certificates = nil
        ssl_certificates = [@gateway_attributes[:ssl_certificate]] if certificate_exist

        @application_gateway.gateways.create(
          name: @ag_name,
          location: location,
          resource_group: @resource_group_name,
          sku_name: @gateway_attributes[:gateway_sku],
          sku_tier: 'Standard',
          sku_capacity: 2,
          gateway_ip_configurations: [
            @gateway_attributes[:gateway_configuration]
          ],
          frontend_ip_configurations: [
            @gateway_attributes[:frontend_ip_config]
          ],
          frontend_ports: [
            @gateway_attributes[:gateway_port]
          ],
          backend_address_pools: [
            @gateway_attributes[:backend_address_pool]
          ],
          backend_http_settings_list: [
            @gateway_attributes[:https_settings]
          ],
          http_listeners: [
            @gateway_attributes[:listener]
          ],
          request_routing_rules: [
            @gateway_attributes[:gateway_request_routing_rule]
          ],
          ssl_certificates: ssl_certificates
        )
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("FATAL ERROR creating Gateway....: #{e.body}")
      rescue => e
        OOLog.fatal("Gateway creation error....: #{e.message}")
      end
    end

    def delete
      begin
        @application_gateway.gateways.get(@resource_group_name, @ag_name).destroy
      rescue MsRestAzure::AzureOperationError => e
        OOLog.fatal("FATAL ERROR deleting Gateway....: #{e.body}")
      rescue => e
        OOLog.fatal("Gateway deleting error....: #{e.body}")
      end
    end
  end
end
