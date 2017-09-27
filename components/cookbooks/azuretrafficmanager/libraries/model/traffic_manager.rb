# Traffic Manager Model
class TrafficManager
  module ProfileStatus
    ENABLED = 'Enabled'.freeze
    DISABLED = 'Disabled'.freeze
  end

  module RoutingMethod
    PERFORMANCE = 'Performance'.freeze
    WEIGHTED = 'Weighted'.freeze
    PRIORITY = 'Priority'.freeze
  end

  GLOBAL = 'global'.freeze

  def initialize(routing_method, dns_config, monitor_config, endpoints)
    raise ArgumentError, 'routing_method is nil' if routing_method.nil?
    raise ArgumentError, 'dns_config is nil' if dns_config.nil?
    raise ArgumentError, 'monitor_config is nil' if monitor_config.nil?
    raise ArgumentError, 'endpoints is nil' if endpoints.nil?

    @routing_method = routing_method
    @dns_config = dns_config
    @monitor_config = monitor_config
    @endpoints = endpoints
    @profile_status = ProfileStatus::ENABLED
    @location = GLOBAL
  end

  attr_reader :routing_method, :dns_config, :monitor_config, :profile_status, :location, :endpoints

  def set_profile_status=(profile_status)
    @profile_status = profile_status
  end
end
