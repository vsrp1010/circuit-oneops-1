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

require 'openssl'
require 'base64'

cloud_name = node[:workorder][:cloud][:ciName]
compute_service = node[:workorder][:services][:compute][cloud_name][:ciAttributes]

nsPathParts = node["workorder"]["rfcCi"]["nsPath"].split("/")
service_name = nsPathParts[1].downcase+'-'+node.workorder.box.ciId.to_s+'-'+node[:workorder][:cloud][:ciId].to_s

rfcCi = node["workorder"]["rfcCi"]
nsPathParts = rfcCi["nsPath"].split("/")
customer_domain = node["customer_domain"]

Chef::Log.info("compute::delete -- name: #{node.server_name} hostname: #{node.vmhostname} service: #{service_name} domain: #{customer_domain} provider: #{cloud_name}")
Chef::Log.debug("rfcCi attrs:"+rfcCi["ciAttributes"].inspect.gsub("\n"," "))

# management certificate
pkcs12 = OpenSSL::PKCS12.new Base64.decode64(compute_service[:certificate]), ''
mgmt_cert_file = "#{Chef::Config[:file_cache_path]}/mgmt.#{node.vmhostname}.pem"

file mgmt_cert_file do
  content pkcs12.certificate.to_s + pkcs12.key.to_s
  action :create
end

Azure.configure do |config|
  config.management_certificate = mgmt_cert_file
  config.subscription_id        = compute_service[:subscription]
  config.management_endpoint    = compute_service[:endpoint]
end


ruby_block 'delete server' do
  block do

    virtual_machine_service = Azure::VirtualMachineManagementService.new

    # retry for 2min for server to be deleted
    ok=false
    attempt = 0
    max_attempts = 6
    interval = 30
    while !ok && attempt<max_attempts
      server = virtual_machine_service.get_virtual_machine(node.vmhostname, service_name)
      if (server.nil?)
        ok = true
        Chef::Log.info("server deleted.")
      else
        Chef::Log.info("found server: #{server.inspect}")
        attempt += 1
        Chef::Log.info("delete attempt: #{attempt}")
        begin
          resp = virtual_machine_service.delete_virtual_machine(node.vmhostname, service_name)
          Chef::Log.info(resp.inspect)
        rescue Exception =>e
          puts "***FAULT:FATAL="+e.message
          e = Exception.new("no backtrace")
          e.set_backtrace("")
          raise e
        end
        sleep interval
      end
    end

    if !ok
      Chef::Log.error("server still not in removed after #{max_attempts} attempts over #{max_attempts*interval} seconds, giving up...")
      exit 1
    end

  end
end


# cleanup temp files
file mgmt_cert_file do
  action :delete
end
