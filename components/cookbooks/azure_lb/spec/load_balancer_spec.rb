require 'simplecov'
SimpleCov.start
require 'rest-client'

require File.expand_path('../../libraries/load_balancer.rb', __FILE__)
require 'fog/azurerm'

describe AzureNetwork::LoadBalancer do
  before do
    credentials= {
        tenant_id: '<TENANT_ID>',
        client_secret: '<CLIENT_SECRET>',
        client_id: '<CLIENT_ID>',
        subscription_id: '<SUBSCRIPTION>'
    }
    @load_balancer = AzureNetwork::LoadBalancer.new(credentials)
    @mock_load_balancer =  Fog::Network::AzureRM::LoadBalancer.new(
      name: 'Test-LB',
      resource_group: 'Test-LB-RG'
    )
    @load_balancer_hash = {
      name: 'Test-LB',
      resource_group: 'Test-LB-RG'
  }
  end

  describe '#get_subscription_load_balancers' do
    it 'gets load balancers in subscription successfully' do
      allow(@load_balancer.azure_network_service).to receive(:load_balancers).and_return([@mock_load_balancer])
      @load_balancer.get_subscription_load_balancers.each do |load_balancer_result|
        expect(load_balancer_result.name).to eq('Test-LB')
      end
    end

    it 'raises AzureOperationError exception while getting load balancers in subscription' do
      exception = MsRestAzure::AzureOperationError.new('Errors')
      allow(@load_balancer.azure_network_service).to receive(:load_balancers).and_raise(exception)
      @load_balancer.get_subscription_load_balancers.each do |load_balancer_result|
        expect(load_balancer_result.name).to eq(nil)
      end
    end
  end

  describe '#get_resource_group_load_balancers' do
    it 'gets load balancers in resource group successfully' do
      allow(@load_balancer.azure_network_service).to receive(:load_balancers).and_return([@mock_load_balancer])
      @load_balancer.get_resource_group_load_balancers('Test-LB-RG').each do |load_balancer_result|
      expect(load_balancer_result.name).to eq('Test-LB')
      end
    end

    it 'raises AzureOperationError exception while getting load balancers in resource group' do
      exception = MsRestAzure::AzureOperationError.new('Errors')
      allow(@load_balancer.azure_network_service).to receive(:load_balancers).and_raise(exception)
      @load_balancer.get_resource_group_load_balancers('Test-LB-RG').each do |load_balancer_result|
      expect(load_balancer_result.name).to eq(nil)
      end
    end
  end

  describe '#get' do
    it 'gets single load balancer successfully' do
      allow(@load_balancer.azure_network_service).to receive_message_chain(:load_balancers, :get).and_return([@mock_load_balancer])
      expect(@load_balancer.get('Test-LB-RG', 'Test-LB')).to_not eq(nil)
    end

    it 'raises AzureOperationError exception while getting a single load balancer' do
      exception = MsRestAzure::AzureOperationError.new(nil, nil, 'error' => { 'code' => 400, 'message' => 'mocked exception' })
      allow(@load_balancer.azure_network_service).to receive_message_chain(:load_balancers, :get).and_raise(exception)
      load_balancer_result = @load_balancer.get('Test-LB-RG', 'Test-LB')
      expect(load_balancer_result.name).to eq(nil)
    end
  end

  describe '#create_update' do
    it 'creates load balancer successfully' do
      allow(@load_balancer.azure_network_service).to receive_message_chain(:load_balancers, :create).and_return([@mock_load_balancer])
      expect(@load_balancer.create_update(@load_balancer_hash)).to_not eq(nil)
    end

    it 'raises AzureOperationError exception while creating a load balancer' do
      exception = MsRestAzure::AzureOperationError.new(nil, nil, 'error' => { 'code' => 400, 'message' => 'mocked exception' })
      allow(@load_balancer.azure_network_service).to receive_message_chain(:load_balancers, :create).and_raise(exception)
      expect { @load_balancer.create_update(@load_balancer_hash) }.to raise_error('no backtrace')
    end

    it 'raises exception while creating a load balancer' do
      allow(@load_balancer.azure_network_service).to receive_message_chain(:load_balancers, :create)
                                                           .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @load_balancer.create_update(@load_balancer_hash) }.to raise_error('no backtrace')
    end
  end

  describe '#delete' do
    it 'deletes load balancer successfully' do
      allow(@load_balancer.azure_network_service).to receive_message_chain(:load_balancers, :delete).and_return(true)
      expect(@load_balancer.delete('Test-LB-RG', 'Test-LB')).to eq(true)
    end

    it 'raises AzureOperationError exception while deleting load balancer' do
      exception = MsRestAzure::AzureOperationError.new(nil, nil, 'error' => { 'code' => 400, 'message' => 'mocked exception' })
      allow(@load_balancer.azure_network_service).to receive_message_chain(:load_balancers, :delete).and_raise(exception)
      expect { @load_balancer.delete('Test-LB-RG', 'Test-LB') }.to raise_error('no backtrace')
    end

    it 'raises exception while deleting load balancer' do
      allow(@load_balancer.azure_network_service).to receive_message_chain(:load_balancers, :delete)
                                                         .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @load_balancer.delete('Test-LB-RG', 'Test-LB') }.to raise_error('no backtrace')
    end
  end

  describe '#create_frontend_ipconfig' do
    it 'creates frontend ipconfiguration successfully when subnet is nil' do
      public_ip_address = double
      allow(public_ip_address).to receive(:id) { '/subscriptions/{guid}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/publicIPAddresses/Test-public-ip' }
      frontend_ipconfig = AzureNetwork::LoadBalancer.create_frontend_ipconfig('Test-Frontend',
                                                                              public_ip_address,
                                                                              nil)
      expect(frontend_ipconfig[:name]).to eq('Test-Frontend')
    end
      it 'creates frontend ipconfiguration successfully when public ip is nil' do
        subnet = double
        allow(subnet).to receive(:id) { '/subscriptions/{guid}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualNetworks/myvnet1/subnets/Test-Subnet' }
        frontend_ipconfig = AzureNetwork::LoadBalancer.create_frontend_ipconfig('Test-Frontend',
                                                                                nil,
                                                                                subnet)
        expect(frontend_ipconfig[:name]).to eq('Test-Frontend')
    end
  end

  describe '#create_probe' do
    it 'creates probe successfully' do
      probe = AzureNetwork::LoadBalancer.create_probe('Test-probe', 'Tcp', 8080, 5, 16, 'myprobeapp1/myprobe1.svc')
      expect(probe[:name]).to eq('Test-probe')
    end
  end

  describe '#create_lb_rule' do
    it 'creates lb rule successfully' do
      probe_id = '/subscriptions/{guid}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/loadBalancers/myLB1/probes/Test-Probe'
      frontend_ipconfig_id = '/subscriptions/{guid}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/loadBalancers/myLB1/frontendIPConfigurations/Test-IP'
      backend_address_pool_id = "/subscriptions/{guid}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/loadBalancers/myLB1/backendAddressPool/pool1"
      lb_rule = AzureNetwork::LoadBalancer.create_lb_rule('Test-LB-Rule', 'Default', 'Tcp', 80, 8080, probe_id, frontend_ipconfig_id, backend_address_pool_id)
      expect(lb_rule[:name]).to eq('Test-LB-Rule')
    end
  end

  describe '#create_inbound_nat_rule' do
    it 'creates inbound nat rule successfully' do
      frontend_ipconfig_id = '/subscriptions/{guid}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/loadBalancers/myLB1/frontendIPConfigurations/Test-IP'
      lb_rule = AzureNetwork::LoadBalancer.create_inbound_nat_rule('Test-Nat-Rule', 'Tcp', frontend_ipconfig_id, 3389, 3389)
      expect(lb_rule[:name]).to eq('Test-Nat-Rule')
    end
  end

  describe '#get_lb' do
    it 'gets load balancer hash successfully' do
      lb = AzureNetwork::LoadBalancer.get_lb('Test-LB-RG', 'Test-LB', 'eastus', 'frontend_ip_configs', 'backend_address_pools', 'lb_rules', 'nat_rules', 'probes')
      expect(lb[:name]).to eq('Test-LB')
    end
  end
end
