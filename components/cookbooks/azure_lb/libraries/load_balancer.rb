require 'fog/azurerm'
require 'chef'
require File.expand_path('../../../azure_base/libraries/logger.rb', __FILE__)

module AzureNetwork
  # Operations of Load Balancer Class
  class LoadBalancer
    # include Azure::ARM::Network
    # include Azure::ARM::Network::Models

    attr_accessor :azure_network_service

    def initialize(creds)
      @azure_network_service = Fog::Network::AzureRM.new(creds)
    end

    def get_subscription_load_balancers
      begin
        OOLog.info('Fetching load balancers from subscription')
        start_time = Time.now.to_i
        result = @azure_network_service.load_balancers
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue MsRestAzure::AzureOperationError => e
        OOLog.info('Error fetching load balancers from subscription')
        OOLog.info("Error response: #{e.response}")
        OOLog.info("Error body: #{e.body}")
        result = [Fog::Network::AzureRM::LoadBalancer.new(service: @azure_network_service)]
        return result
      end
      OOLog.info("operation took #{duration} seconds")
      result
    end

    def get_resource_group_load_balancers(resource_group_name)
      begin
        OOLog.info("Fetching load balancers from '#{resource_group_name}'")
        start_time = Time.now.to_i
        result = @azure_network_service.load_balancers(resource_group: resource_group_name)
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue MsRestAzure::AzureOperationError => e
        OOLog.info("Error fetching load balancers from '#{resource_group_name}'")
        OOLog.info("Error Response: #{e.response}")
        OOLog.info("Error Body: #{e.body}")
        result = [Fog::Network::AzureRM::LoadBalancer.new(service: @azure_network_service)]
        return result
      end
      OOLog.info("operation took #{duration} seconds")
      result
    end

    def get(resource_group_name, load_balancer_name)
      begin
        OOLog.info("Fetching load balancer '#{load_balancer_name}' from '#{resource_group_name}' ")
        start_time = Time.now.to_i
        result = @azure_network_service.load_balancers.get(resource_group_name, load_balancer_name)
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue => e
        OOLog.info("Error getting LoadBalancer '#{load_balancer_name}' in ResourceGroup '#{resource_group_name}' ")
        OOLog.info("Error Message: #{e.message}")
        return nil
      end
      OOLog.info("operation took #{duration} seconds")
      result
    end

    def create_update(load_balancer)
      begin
        OOLog.info("Creating/Updating load balancer '#{load_balancer[:name]}' in '#{load_balancer[:resource_group]}' ")
        start_time = Time.now.to_i
        result = @azure_network_service.load_balancers.create(load_balancer)
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue  MsRestAzure::AzureOperationError => e
        msg = "Error Code: #{e.body['error']['code']}"
        msg += "Error Message: #{e.body['error']['message']}"
        OOLog.fatal("Error creating/updating load balancer '#{load_balancer[:name]}'. #{msg} ")
      rescue => ex
        OOLog.fatal("Error creating/updating load balancer '#{load_balancer[:name]}'. #{ex.message} ")
      end
      OOLog.info("operation took #{duration} seconds")
      result
    end

    def delete(resource_group_name, load_balancer_name)
      begin
        OOLog.info("Deleting load balancer '#{load_balancer_name}' from '#{resource_group_name}' ")
        start_time = Time.now.to_i
        result = @azure_network_service.load_balancers.get(resource_group_name, load_balancer_name).destroy
        end_time = Time.now.to_i
        duration = end_time - start_time
      rescue  MsRestAzure::AzureOperationError => e
        msg = "Error Code: #{e.body['error']['code']}"
        msg += "Error Message: #{e.body['error']['message']}"
        OOLog.fatal("Error deleting load balancer '#{load_balancer_name}'. #{msg} ")
      rescue => ex
        OOLog.fatal("Error deleting load balancer '#{load_balancer_name}'. #{ex.message} ")
      end
      OOLog.info("operation took #{duration} seconds")
      result
    end

    # ===== Static Methods =====

    def self.create_frontend_ipconfig(frontend_name, public_ip, subnet)
      # Frontend IP configuration, a Load balancer can include one or more frontend IP addresses,
      # otherwise known as a virtual IPs (VIPs). These IP addresses serve as ingress for the traffic.
      if public_ip.nil?
        frontend_ipconfig = {
          name: frontend_name,
          private_ipallocation_method: 'Dynamic',
          subnet_id: subnet.id
        }
      else
        frontend_ipconfig = {
          name: frontend_name,
          private_ipallocation_method: 'Dynamic',
          public_ipaddress_id: public_ip.id
        }
      end
      frontend_ipconfig
    end

    def self.create_probe(probe_name, protocol, port, interval_secs, num_probes, request_path)
      # Probes, probes enable you to keep track of the health of VM instances.
      # If a health probe fails, the VM instance will be taken out of rotation automatically.
      {
          name: probe_name,
          protocol: protocol,
          request_path: request_path,
          port: port,
          interval_in_seconds: interval_secs,
          number_of_probes: num_probes
      }
    end

    def self.create_lb_rule(lb_rule_name, load_distribution, protocol, frontend_port, backend_port, probe_id, frontend_ipconfig_id, backend_address_pool_id)
      # Load Balancing Rule: a rule property maps a given frontend IP and port combination to a set
      # of backend IP addresses and port combination.
      # With a single definition of a load balancer resource, you can define multiple load balancing rules,
      # each rule reflecting a combination of a frontend IP and port and backend IP and port associated with VMs.

      {
          name: lb_rule_name,
          frontend_ip_configuration_id: frontend_ipconfig_id,
          backend_address_pool_id: backend_address_pool_id,
          probe_id: probe_id,
          protocol: protocol,
          frontend_port: frontend_port,
          backend_port: backend_port,
          enable_floating_ip: false,
          idle_timeout_in_minutes: 5,
          load_distribution: load_distribution
      }
    end

    def self.create_inbound_nat_rule(nat_rule_name, protocol, frontend_ipconfig_id, frontend_port, backend_port)
      # Inbound NAT rules, NAT rules defining the inbound traffic flowing through the frontend IP
      # and distributed to the back end IP.
      {
          name: nat_rule_name,
          frontend_ip_configuration_id: frontend_ipconfig_id,
          protocol: protocol,
          frontend_port: frontend_port,
          backend_port: backend_port
      }
    end

    def self.get_lb(resource_group_name, lb_name, location, frontend_ip_configs, backend_address_pools, lb_rules, nat_rules, probes)
      {
          name: lb_name,
          resource_group: resource_group_name,
          location: location,
          frontend_ip_configurations: frontend_ip_configs,
          backend_address_pool_names: backend_address_pools,
          load_balancing_rules: lb_rules,
          inbound_nat_rules: nat_rules,
          probes: probes
      }
    end
  end
end
