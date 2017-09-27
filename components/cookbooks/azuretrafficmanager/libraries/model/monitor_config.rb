# Monitor Configuration Model for Traffic Manager
class MonitorConfig
  module Protocol
    HTTP = 'HTTP'.freeze
    HTTPS = 'HTTPS'.freeze
  end

  def initialize(protocol, port, path)
    raise ArgumentError, 'protocol is nil' if protocol.nil?
    raise ArgumentError, 'port is nil' if port.nil?
    raise ArgumentError, 'path is nil' if path.nil?

    @protocol = protocol
    @port = port
    @path = path
  end

  attr_reader :protocol, :port, :path
end
