# Copyright 2016, Walmart Stores, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# wait for ssh to be open
require 'socket'
require 'timeout'
port_closed = true
retry_count = 0
ruby_block 'ssh port wait' do
  block do

    if node[:ip].nil?
      puts "***FAULT:FATAL=ip missing"
      Chef::Log.error("no ip")
      e = Exception.new("no backtrace")
      e.set_backtrace("")
      raise e
    end

   if node.has_key?('max_retry_count_add')
      max_retry_count = node[:max_retry_count_add]
    else
      max_retry_count = 10
    end

    ip = node[:ip]
    port = 22
    if node[:ip].include?(":")
      parts = node[:ip].split(":")
      ip = parts.first
      port = parts.last
    end

    while port_closed && retry_count < max_retry_count do
      begin
        Timeout::timeout(5) do
          begin
            TCPSocket.new(ip, port).close
            port_closed = false
            Chef::Log.info("ssh port open")
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
          end
        end
      rescue Timeout::Error
      end
      if port_closed
        Chef::Log.info("waiting for ssh port #{ip}:#{port} 10sec ")
        sleep 5
      end
      retry_count += 1
    end
    Chef::Log.info("ssh port closed") if port_closed

    node.set[:ssh_port_closed] = port_closed

  end
end
