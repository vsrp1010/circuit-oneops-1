# DNS Configuration Model
class DnsConfig
  def initialize(relative_name, ttl)
    raise ArgumentError, 'relative_name is nil' if relative_name.nil?
    raise ArgumentError, 'ttl is nil' if ttl.nil?

    @relative_name = relative_name
    @ttl = ttl
  end

  attr_reader :relative_name, :ttl
end
