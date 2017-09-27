require 'rspec'
require 'json'
require 'ms_rest'

require ::File.expand_path('../../libraries/public_ip.rb', __FILE__)
require ::File.expand_path('../../../azure/libraries/public_ip.rb', __FILE__)
require ::File.expand_path('../../../azure_base/libraries/logger', __FILE__)
require ::File.expand_path('../../../azure_base/libraries/utils', __FILE__)

describe 'Azuredns::public_ip' do
  file_path = File.expand_path('update_dns_on_pip_data.json', __dir__)
  file = File.open(file_path)
  contents = file.read
  node = JSON.parse(contents)
  credentials = {
      tenant_id: '<TENANT_ID>',
      client_secret: '<CLIENT_SECRET>',
      client_id: '<CLIENT_ID>',
      subscription_id: '<SUBSCRIPTION>'
  }
  cloud_name = node['workorder']['cloud']['ciName']
  dns_attributes = node['workorder']['services']['dns'][cloud_name]['ciAttributes']
  resource_group = node['platform-resource-group']
  zone_name = dns_attributes['zone'].split('.').reverse.join('.').partition('.').last.split('.').reverse.join('.').tr('.', '-')

  dns_public_ip = AzureDns::PublicIp.new(resource_group, credentials, zone_name)

  describe 'PublicIp::update_dns' do
    it 'returns nil if node.app_name is "os"' do
      node['app_name'] = 'os'
      allow(dns_public_ip.pubip).to receive(:get).and_return(Fog::Network::AzureRM::PublicIp.new)
      allow(dns_public_ip.pubip).to receive(:create_update).and_return(Fog::Network::AzureRM::PublicIp.new)
      expect(dns_public_ip.update_dns(node)).to be_nil
    end

    it 'returns nil if node.app_name is "fqdn"' do
      node['app_name'] = 'fqdn'
      allow(dns_public_ip.pubip).to receive(:get).and_return(Fog::Network::AzureRM::PublicIp.new)
      allow(dns_public_ip.pubip).to receive(:create_update).and_return(Fog::Network::AzureRM::PublicIp.new)
      allow(dns_public_ip).to receive(:update_dns_for_fqdn).and_return('fqdn-response')
      expect(dns_public_ip.update_dns(node)).to be_nil
    end

    it 'returns domain-name-label if node.app_name is "lb"' do
      node['app_name'] = 'lb'
      expect(dns_public_ip.update_dns(node)).to eq('lb-compute-1189982-1-1578346-s3rss-test-php-mysql-oneops-one')
    end
  end

  describe 'PublicIp::update_dns_for_os' do
    node['app_name'] = 'os'
    it 'returns nil if node.full_hostname is nil' do
      node['full_hostname'] = nil
      allow(dns_public_ip.pubip).to receive(:get).and_return(Fog::Network::AzureRM::PublicIp.new)
      allow(dns_public_ip.pubip).to receive(:create_update).and_return(Fog::Network::AzureRM::PublicIp.new)
      expect(dns_public_ip.update_dns_for_os(node)).to be_nil
    end

    it 'returns not nil if node.full_hostname is not nil' do
      node['full_hostname'] = 'test-php-mysql.oneops.com'
      allow(dns_public_ip.pubip).to receive(:get).and_return(Fog::Network::AzureRM::PublicIp.new)
      allow(dns_public_ip.pubip).to receive_message_chain(:create_update ).and_return(Fog::Network::AzureRM::PublicIp.new)
      expect(dns_public_ip.update_dns_for_os(node)).not_to be_nil
    end
  end

  describe 'PublicIp::update_dns_for_fqdn' do
    node['app_name'] = 'fqdn'
    it 'returns not nil if node.app_name is "fqdn"' do
      allow(dns_public_ip.pubip).to receive(:get).and_return(Fog::Network::AzureRM::PublicIp.new)
      allow(dns_public_ip.pubip).to receive(:create_update).and_return(Fog::Network::AzureRM::PublicIp.new)
      expect(dns_public_ip.update_dns_for_fqdn(node)).not_to be_nil
    end

    it 'returns not nil if aliases are not available' do
      node['workorder']['rfcCi']['ciAttributes']['aliases'] = "[]"
      allow(dns_public_ip.pubip).to receive(:get).and_return(Fog::Network::AzureRM::PublicIp.new)
      allow(dns_public_ip.pubip).to receive(:create_update).and_return(Fog::Network::AzureRM::PublicIp.new)
      expect(dns_public_ip.update_dns_for_fqdn(node)).not_to be_nil
    end

    it 'returns not nil if availability is "single"' do
      node['workorder']['box']['ciAttributes']['availability'] = 'single'
      allow(dns_public_ip.pubip).to receive(:get).and_return(Fog::Network::AzureRM::PublicIp.new)
      allow(dns_public_ip.pubip).to receive(:create_update).and_return(Fog::Network::AzureRM::PublicIp.new)
      expect(dns_public_ip.update_dns_for_fqdn(node)).not_to be_nil
    end

    it 'returns lb-list if availability is "redundant"' do
      node['workorder']['box']['ciAttributes']['availability'] = 'redundant'
      allow(dns_public_ip.pubip).to receive(:check_existence_publicip) { true }
      allow(dns_public_ip.pubip).to receive(:get).and_return(Fog::Network::AzureRM::PublicIp.new)
      allow(dns_public_ip.pubip).to receive(:create_update).and_return(Fog::Network::AzureRM::PublicIp.new)
      expect(dns_public_ip.update_dns_for_fqdn(node)).to eq([{"ciId"=>1189945}])
    end
  end

  describe 'PublicIp::update_dns_for_lb' do
    node['app_name'] = 'lb'
    it 'returns domain-name-label if node.app_name is "lb"' do
      expect(dns_public_ip.update_dns_for_lb(node)).to eq('lb-compute-1189982-1-1578346-s3rss-test-php-mysql-oneops-one')
    end
  end

  end