require 'simplecov'
require 'rest-client'
SimpleCov.start
require File.expand_path('../../libraries/network_security_group.rb', __FILE__)
require 'fog/azurerm'

describe AzureNetwork::NetworkSecurityGroup do
  before do
    credentials = {
        tenant_id: '<TENANT_ID>',
        client_secret: '<CLIENT_SECRET>',
        client_id: '<CLIENT_ID>',
        subscription_id: '<SUBSCRIPTION>'
    }
    @network_security_group = AzureNetwork::NetworkSecurityGroup.new(credentials)
    @nsg_response = Fog::Network::AzureRM::NetworkSecurityGroup.new(
      name: 'fog-test-nsg',
      resource_group: 'fog-test-rg'
    )
    @network_security_rule = Fog::Network::AzureRM::NetworkSecurityRule.new(
      name: 'fog-test-nsr',
      resource_group: 'fog-test-rg',
      network_security_group_name: 'fog-test-nsr'
    )
  end

  describe '#get' do
    it 'gets network security group successfully' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_groups, :get).and_return(@nsg_response)
      expect(@network_security_group.get('<RESOURCE_GROUP>', '<NSG_NAME>')).to_not eq(nil)
    end
    it 'returns nil while getting network security group if exception is ResourceNotFound' do
      exception = MsRestAzure::AzureOperationError.new('Errors')
      ex_values = []
      allow(exception).to receive_message_chain(:body, :values) { ex_values.push('code' => 'ResourceNotFound') }
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_groups, :get)
        .and_raise(exception)

      expect(@network_security_group.get('<RESOURCE_GROUP>', '<NSG_NAME>')).to eq(nil)
    end
    it 'raises AzureOperationError exception while getting network security group' do
      exception = MsRestAzure::AzureOperationError.new('Errors')
      allow(exception).to receive_message_chain(:body, :values) { %w(temp temp1) }
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_groups, :get)
        .and_raise(exception)

      expect { @network_security_group.get('<RESOURCE_GROUP>', '<NSG_NAME>') }.to raise_error('no backtrace')
    end
    it 'raises exception while getting network security group' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_groups, :get)
        .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @network_security_group.get('<RESOURCE_GROUP>', '<NSG_NAME>') }.to raise_error('no backtrace')
    end
  end

  describe '#create' do
    it 'creates network security group successfully' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_groups, :create).and_return(@nsg_response)
      expect(@network_security_group.create('<RESOURCE_GROUP>', '<NSG_NAME>', 'east-us')).to_not eq(nil)
    end
    it 'raises AzureOperationError exception while creating network security group' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_groups, :create)
        .and_raise(MsRestAzure::AzureOperationError.new('Errors'))

      expect { @network_security_group.create('<RESOURCE_GROUP>', '<NSG_NAME>', 'east-us') }.to raise_error('no backtrace')
    end
    it 'raises exception while creating network security group' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_groups, :create)
        .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @network_security_group.create('<RESOURCE_GROUP>', '<NSG_NAME>', 'east-us') }.to raise_error('no backtrace')
    end
  end

  describe '#create_update' do
    it 'creates/updates network security group successfully' do
      parameters = double
      allow(parameters).to receive(:location) { '<LOCATION>' }
      allow(parameters).to receive(:security_rules) { '<SECURITY_RULE>' }
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_groups, :create).and_return(@nsg_response)
      expect(@network_security_group.create_update('<RESOURCE_GROUP>', '<NSG_NAME>', parameters)).to_not eq(nil)
    end
    it 'raises AzureOperationError exception while creating/updating network security group' do
      parameters = double
      allow(parameters).to receive(:location) { '<LOCATION>' }
      allow(parameters).to receive(:security_rules) { '<SECURITY_RULE>' }
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_groups, :create)
        .and_raise(MsRestAzure::AzureOperationError.new('Errors'))

      expect { @network_security_group.create_update('<RESOURCE_GROUP>', '<NSG_NAME>', parameters) }.to raise_error('no backtrace')
    end
    it 'raises exception while creating/updating network security group' do
      parameters = double
      allow(parameters).to receive(:location) { '<LOCATION>' }
      allow(parameters).to receive(:security_rules) { '<SECURITY_RULE>' }
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_groups, :create)
        .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @network_security_group.create_update('<RESOURCE_GROUP>', '<NSG_NAME>', parameters) }.to raise_error('no backtrace')
    end
  end

  describe '#list_security_groups' do
    it 'list all network security groups successfully' do
      allow(@network_security_group.network_client).to receive(:network_security_groups).and_return([@nsg_response])
      expect(@network_security_group.list_security_groups('<RESOURCE_GROUP>')).to_not eq(nil)
    end
    it 'raises AzureOperationError exception while listing network security groups' do
      allow(@network_security_group.network_client).to receive(:network_security_groups)
        .and_raise(MsRestAzure::AzureOperationError.new('Errors'))

      expect { @network_security_group.list_security_groups('<RESOURCE_GROUP>') }.to raise_error('no backtrace')
    end
    it 'raises exception while listing network security groups' do
      allow(@network_security_group.network_client).to receive(:network_security_groups)
        .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @network_security_group.list_security_groups('<RESOURCE_GROUP>') }.to raise_error('no backtrace')
    end
  end

  describe '#delete_security_group' do
    it 'deletes network security group successfully' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_groups, :get, :destroy).and_return(true)

      expect(@network_security_group.delete_security_group('<RESOURCE_GROUP>', '<NSG_NAME>')).to eq(true)
    end
    it 'raises AzureOperationError exception' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_groups, :get, :destroy)
        .and_raise(MsRestAzure::AzureOperationError.new('Errors'))

      expect(@network_security_group.delete_security_group('<RESOURCE_GROUP>', '<NSG_NAME>')).to eq(nil)
    end
    it 'raises exception while deleting network security group' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_groups, :get, :destroy)
        .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @network_security_group.delete_security_group('<RESOURCE_GROUP>', '<NSG_NAME>') }.to raise_error('no backtrace')
    end
  end

  describe '#create_or_update_rule' do
    parameters = {
      protocol: 'tcp',
      source_port_range: '22',
      destination_port_range: '22',
      source_address_prefix: '0.0.0.0/0',
      destination_address_prefix: '0.0.0.0/0',
      access: 'Allow',
      priority: '100',
      direction: 'Inbound'
    }
    it 'creates network security rule successfully' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_rules, :create).and_return(@network_security_rule)
      expect(@network_security_group.create_or_update_rule('<RESOURCE_GROUP>', '<NSG_NAME>', '<NSG_RULE_NAME>', parameters)).to eq(@network_security_rule)
    end
    it 'raises AzureOperationError exception while creating network security rule' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_rules, :create)
        .and_raise(MsRestAzure::AzureOperationError.new('Errors'))

      expect { @network_security_group.create_or_update_rule('<RESOURCE_GROUP>', '<NSG_NAME>', '<NSG_RULE_NAME>', parameters) }.to raise_error('no backtrace')
    end
    it 'raises exception while creating network security rule' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_rules, :create)
        .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @network_security_group.create_or_update_rule('<RESOURCE_GROUP>', '<NSG_NAME>', '<NSG_RULE_NAME>', parameters) }.to raise_error('no backtrace')
    end
  end

  describe '#get_rule' do
    it 'gets network security rule successfully' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_rules, :get).and_return(@network_security_rule)
      expect(@network_security_group.get_rule('<RESOURCE_GROUP>', '<NSG_NAME>', '<NSG_RULE_NAME>')).to eq(@network_security_rule)
    end
    it 'raises AzureOperationError exception while getting network security rule' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_rules, :get)
        .and_raise(MsRestAzure::AzureOperationError.new('Errors'))

      expect { @network_security_group.get_rule('<RESOURCE_GROUP>', '<NSG_NAME>', '<NSG_RULE_NAME>') }.to raise_error('no backtrace')
    end
    it 'raises exception while getting network security rule' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_rules, :get)
        .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @network_security_group.get_rule('<RESOURCE_GROUP>', '<NSG_NAME>', '<NSG_RULE_NAME>') }.to raise_error('no backtrace')
    end
  end

  describe '#delete_rule' do
    it 'deletes network security rule successfully' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_rules, :get, :destroy).and_return(true)
      expect(@network_security_group.delete_rule('<RESOURCE_GROUP>', '<NSG_NAME>', '<NSG_RULE_NAME>')).to eq(true)
    end
    it 'raises AzureOperationError exception while deleting network security rule' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_rules, :get, :destroy)
        .and_raise(MsRestAzure::AzureOperationError.new('Errors'))

      expect { @network_security_group.delete_rule('<RESOURCE_GROUP>', '<NSG_NAME>', '<NSG_RULE_NAME>') }.to raise_error('no backtrace')
    end
    it 'raises exception while deleting network security rule' do
      allow(@network_security_group.network_client).to receive_message_chain(:network_security_rules, :get, :destroy)
        .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @network_security_group.delete_rule('<RESOURCE_GROUP>', '<NSG_NAME>', '<NSG_RULE_NAME>') }.to raise_error('no backtrace')
    end
  end

  describe '#list_rules' do
    it 'list all network security rules successfully' do
      allow(@network_security_group.network_client).to receive(:network_security_rules).and_return([@network_security_rule])
      expect(@network_security_group.list_rules('<RESOURCE_GROUP>', '<NSG_NAME>')).to eq([@network_security_rule])
    end
    it 'raises AzureOperationError exception while listing network security rules' do
      allow(@network_security_group.network_client).to receive(:network_security_rules)
        .and_raise(MsRestAzure::AzureOperationError.new('Errors'))

      expect { @network_security_group.list_rules('<RESOURCE_GROUP>', '<NSG_NAME>') }.to raise_error('no backtrace')
    end
    it 'raises exception while listing network security rules' do
      allow(@network_security_group.network_client).to receive(:network_security_rules)
        .and_raise(MsRest::HttpOperationError.new('Error'))

      expect { @network_security_group.list_rules('<RESOURCE_GROUP>', '<NSG_NAME>') }.to raise_error('no backtrace')
    end
  end

  describe '#self.create_rule_properties' do
    it 'retrieves rule properties successfully' do
      properties = AzureNetwork::NetworkSecurityGroup.create_rule_properties('security_rule_name', 'access', 'destination_address_prefix', 'destination_port_range', 'direction', 'priority', 'protocol', 'source_address_prefix', 'source_port_range')
      expect(properties[:protocol]).to eq('protocol')
    end
  end
end
