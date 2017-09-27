# Endpoint Model for Traffic Manager
class EndPoint
  module Status
    ENABLED = 'Enabled'.freeze
    DISABLED = 'Disabled'.freeze
  end

  TYPE = 'externalEndpoints'.freeze

  def initialize(name, target, location)
    raise ArgumentError, 'name is nil' if name.nil?
    raise ArgumentError, 'target is nil' if target.nil?
    raise ArgumentError, 'location is nil' if location.nil?

    @name = name
    @type = TYPE
    @target = target
    @location = location
  end

  attr_reader :name, :target, :location, :type

  def set_endpoint_status(endpoint_status)
    @endpoint_status = endpoint_status
  end

  def set_weight(weight)
    @weight = weight
  end

  def set_priority(priority)
    @priority = priority
  end

  attr_reader :endpoint_status, :weight, :priority
end
