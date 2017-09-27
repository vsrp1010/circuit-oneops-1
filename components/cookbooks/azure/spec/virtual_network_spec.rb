require 'json'
require 'fog/azurerm'
require 'simplecov'
SimpleCov.start

require File.expand_path('../../libraries/virtual_network', __FILE__)
require File.expand_path('../../libraries/subnet', __FILE__)
require ::File.expand_path('../../../azure_base/libraries/logger', __FILE__)
require ::File.expand_path('../../../azure_base/libraries/utils', __FILE__)

describe AzureNetwork::VirtualNetwork do
  before :each do
    credentials = {
        tenant_id: '<TENANT_ID>',
        client_secret: '<CLIENT_SECRET>',
        client_id: '<CLIENT_ID>',
        subscription_id: '<SUBSCRIPTION>'
    }
    @platform_resource_group = '<RESOURCE-GROUP-NAME>'
    @azure_client = AzureNetwork::VirtualNetwork.new(credentials)
    @azure_client.name = '<VNET-NAME>'

    @fog_vnetwork = Fog::Network::AzureRM::VirtualNetwork.new
    @fog_vnetwork.subnets = []
  end

  describe '# test build_network_object functionality' do
    it 'builds desired object successfully' do
      @azure_client.dns_list = ['10.10.1.12']
      @azure_client.sub_address = ['12.11.1.1']
      @azure_client.name = 'vnet-name'
      @azure_client.location = 'eastus'
      @fog_vnetwork.location = 'eastus'

      subnet = Fog::Network::AzureRM::Subnet.new
      subnet.name = 'subnet_0_vnet-name'
      subnet.address_prefix = '10.15.1.16'

      @fog_vnetwork.subnets = [subnet]
      @fog_vnetwork.dns_servers = ['1.1.1.1']

      expect(@azure_client.build_network_object).to be_a Fog::Network::AzureRM::VirtualNetwork
    end

  end

  describe '# test create_update functionality' do
    it 'creates successfully' do
      file_path = File.expand_path('virtual_network_data.json', __dir__)
      file = File.open(file_path)
      vnet_response = file.read

      allow(@azure_client.network_client).to receive_message_chain(:virtual_networks, :create).and_return(vnet_response)
      subnet = Fog::Network::AzureRM::Subnet.new
      subnet.name = 'subnet_0_vnet-name'
      @fog_vnetwork.subnets = [subnet]
      expect(@azure_client.create_update(@platform_resource_group, @fog_vnetwork)).to_not eq(nil)
    end

    it 'raises AzureOperationError exception' do
      allow(@azure_client.network_client).to receive_message_chain(:virtual_networks, :create)
                                                 .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @azure_client.create_update(@platform_resource_group, @fog_vnetwork)}.to raise_error('no backtrace')

    end

    it 'raises a generic exception' do
      allow(@azure_client.network_client).to receive_message_chain(:virtual_networks, :create)
                                                 .and_raise(MsRest::HttpOperationError.new('Error'))
      expect { @azure_client.create_update(@platform_resource_group, @fog_vnetwork) }.to raise_error('no backtrace')
    end
  end

  describe '#test get functionality' do
    it 'successfull case of get functionality' do
      file_path = File.expand_path('virtual_network_data.json', __dir__)
      file = File.open(file_path)
      vnet_response = file.read

      allow(@azure_client.network_client).to receive_message_chain(:virtual_networks, :get).and_return(vnet_response)
      expect(@azure_client.get(@platform_resource_group)).to_not eq(nil)
    end

    it 'raises AzureOperationError exception' do
      allow(@azure_client.network_client).to receive_message_chain(:virtual_networks, :get)
                                                 .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @azure_client.get(@platform_resource_group)}.to raise_error('no backtrace')
    end

    it 'raises a generic exception' do
      allow(@azure_client.network_client).to receive_message_chain(:virtual_networks, :get)
                                                 .and_raise(MsRest::HttpOperationError.new('Error'))
      expect { @azure_client.get(@platform_resource_group) }.to raise_error('no backtrace')
    end
  end

  describe '#test list functionality' do
    it 'successfull case of list functionality' do
      file_path = File.expand_path('virtual_network_data.json', __dir__)
      file = File.open(file_path)
      vnet_response = file.read

      allow(@azure_client.network_client).to receive_message_chain(:virtual_networks).and_return([vnet_response])
      expect(@azure_client.list(@platform_resource_group)).to_not eq(nil)
    end

    it 'raises AzureOperationError exception' do
      allow(@azure_client.network_client).to receive_message_chain(:virtual_networks)
                                                 .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @azure_client.list(@platform_resource_group)}.to raise_error('no backtrace')
    end

    it 'raises a generic exception' do
      allow(@azure_client.network_client).to receive_message_chain(:virtual_networks)
                                                 .and_raise(MsRest::HttpOperationError.new('Error'))
      expect { @azure_client.list(@platform_resource_group) }.to raise_error('no backtrace')
    end
  end

  describe '#test list_all functionality' do
    it 'successfull case of list_all functionality' do
      file_path = File.expand_path('virtual_network_data.json', __dir__)
      file = File.open(file_path)
      vnet_response = file.read


      allow(@azure_client.network_client).to receive_message_chain(:virtual_networks).and_return([vnet_response])
      expect(@azure_client.list_all).to_not eq(nil)
    end

    it 'raises AzureOperationError exception' do
      allow(@azure_client.network_client).to receive_message_chain(:virtual_networks)
                                                 .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @azure_client.list_all}.to raise_error('no backtrace')
    end

    it 'raises a generic exception' do
      allow(@azure_client.network_client).to receive_message_chain(:virtual_networks)
                                                 .and_raise(MsRest::HttpOperationError.new('Error'))
      expect { @azure_client.list_all}.to raise_error('no backtrace')
    end
  end


  describe '#test exists? functionality' do
    it 'successfull case of checking exist functionality' do
      allow(@azure_client.network_client).to receive_message_chain(:virtual_networks, :check_virtual_network_exists).and_return(true)
      expect(@azure_client.exists?(@platform_resource_group)).to eq(true)
    end

    it 'raises AzureOperationError exception' do
      allow(@azure_client.network_client).to receive_message_chain(:virtual_networks, :check_virtual_network_exists)
                                                 .and_raise(MsRestAzure::AzureOperationError.new('Errors'))
      expect { @azure_client.exists?(@platform_resource_group)}.to raise_error('no backtrace')
    end

    it 'raises a generic exception' do
      allow(@azure_client.network_client).to receive_message_chain(:virtual_networks, :check_virtual_network_exists)
                                                 .and_raise(MsRest::HttpOperationError.new('Error'))
      expect { @azure_client.exists?(@platform_resource_group) }.to raise_error('no backtrace')
    end
  end

  describe '#test get subnet with available ips functionality' do
    it 'successfull return subnet' do

      subnet = Fog::Network::AzureRM::Subnet.new
      subnet.name = 'subnet_0_vnet-name'
      subnet.address_prefix = '10.15.1.16'
      subnet.ip_configurations_ids = nil

      @fog_vnetwork.subnets = [subnet]
      expect(@azure_client.get_subnet_with_available_ips(@fog_vnetwork.subnets, true)).to be_an_instance_of(Fog::Network::AzureRM::Subnet)
      expect(@azure_client.get_subnet_with_available_ips(@fog_vnetwork.subnets, false)).to be_an_instance_of(Fog::Network::AzureRM::Subnet)
    end

    it 'checks if remaining ips are zero in subnet' do
      subnet = Fog::Network::AzureRM::Subnet.new
      subnet.name = 'subnet_0_vnet-name'
      subnet.address_prefix = '10.15.1.16/30'
      subnet.ip_configurations_ids = ['id1', 'id2']

      @fog_vnetwork.subnets = [subnet]
      expect { @azure_client.get_subnet_with_available_ips(@fog_vnetwork.subnets, false) }.to raise_error('no backtrace')
    end
  end

  describe '# test add gateway subnet to vnet' do
    it 'successfuly returns the vnet with gateway subnet' do
      @fog_vnetwork.name = 'TestVnet'
      expect(@azure_client.add_gateway_subnet_to_vnet(@fog_vnetwork, '12.11.1.1', 'GatewaySubnet').name).to eq('TestVnet')
    end

    it 'already has a subnet' do
      subnet = Fog::Network::AzureRM::Subnet.new
      subnet.name = 'GatewaySubnet'
      @fog_vnetwork.subnets.push(subnet)

      subnet = Fog::Network::AzureRM::Subnet.new
      subnet.name = 'subnet_0_vnet-name'

      @fog_vnetwork.subnets.push(subnet)
      @fog_vnetwork.name = 'TestVnet'
      expect(@azure_client.add_gateway_subnet_to_vnet(@fog_vnetwork, '12.11.1.1', 'GatewaySubnet').name).to eq('TestVnet')
    end
  end
end
