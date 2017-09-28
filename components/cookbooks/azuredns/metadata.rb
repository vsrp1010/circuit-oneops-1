name             'Azuredns'
maintainer       'oneops'
maintainer_email 'support@oneops.com'
license          'Apache License, Version 2.0'
description      'Installs/Configures Azure DNS'
version          '0.1.0'
depends          'azure'

grouping 'default',
  :access => "global",
  :packages => [ 'base', 'mgmt.cloud.service', 'cloud.service' ],
  :namespace => true

attribute 'tenant_id',
  :description => "Azure Tenant ID",
  :required => "required",
  :default => "Enter Tenant ID associated with Azure AD",
  :format => {
    :help => 'tenant id',
    :category => '1.Authentication',
    :order => 1
  }

attribute 'subscription',
  :description => "Subscription Id",
  :required => "required",
  :default => "",
  :format => {
    :help => 'subscription id in azure',
    :category => '1.Authentication',
    :order => 2
  }

attribute 'client_id',
  :description => "Client Id",
  :required => "required",
  :default => "",
  :format => {
    :help => 'client id',
    :category => '1.Authentication',
    :order => 3
  }

attribute 'client_secret',
  :description => "Client Secret",
  :encrypted => true,
  :required => "required",
  :default => "",
  :format => {
    :help => 'client secret',
    :category => '1.Authentication',
    :order => 4
  }

attribute 'location',
  :description => "Location",
  :default => "South Central US",
  :format => {
    :help => 'Use the location string',
    :category => '2.Config',
    :order => 5,
    :form => { 'field' => 'select', 'options_for_select' => [
        ['Central US','centralus'],
        ['East US','eastus'],
        ['East US 2','eastus2'],
        ['North Central US','northcentralus'],
        ['South Central US','southcentralus'],
        ['West US','westus']
      ]
    }
  }

attribute 'express_route_enabled',
  :description => "Express Route",
  :default => "false",
  :format => {
      :help => 'An Azure ExpressRoute is a private connections between Azure datacenters and your on-premise infrastructure. ExpressRoute connections do not go over the public Internet.',
      :category => '3.Network Section',
      :order => 6,
      :form => {'field' => 'checkbox'}
  }

attribute 'resource_group',
  :description => "Network Resource Group",
  :default => '',
  :format => {
      :help => 'Mandatory only for private (corporate address space, eg - express route), Fill this with master resource group name which has Predefined Private VNets.',
      :category => '3.Network Section',
      :order => 7,
      :filter => {'all' => {'visible' => 'express_route_enabled:eq:true'}}
  }

attribute 'network',
  :description => "Virtual Network Name",
  :default => '',
  :format => {
      :help => 'Mandatory only for private (corporate address space, eg - express route), Fill this with Predefined Private VNET and subnet (in the field below)name to use.Optional for public ip type,if empty new VNet and subnet will be created',
      :category => '3.Network Section',
      :order => 8,
      :filter => {'all' => {'visible' => 'express_route_enabled:eq:true'}}
  }

attribute 'network_address',
  :description => "Network Address Range",
  :default => '',
  :format => {
      :help => 'One address space in CIDR notation must be added.',
      :category => '3.Network Section',
      :order => 9,
      :filter => {'all' => {'visible' => 'express_route_enabled:eq:false'}}
  }

attribute 'subnet_address',
  :description => "Subnet Address Range",
  :default => '',
  :format => {
      :help => 'Many comma delimited subnet address ranges in CIDR notation may be added.',
      :category => '3.Network Section',
      :order => 10,
      :filter => {'all' => {'visible' => 'express_route_enabled:eq:false'}}
  }


attribute 'zone',
  :description => "Zone",
  :required => "required",
  :default => "",
  :format => {
    :help => 'Specify the zone name where to insert DNS records',
    :category => '4.DNS',
    :order => 1
  }

attribute 'cloud_dns_id',
  :description => "Cloud DNS Id",
  :required => "required",
  :default => "",
  :format => {
    :help => 'Cloud DNS Id - prepended to zone name, but replaced w/ fqdn.global_dns_id for GLB',
    :category => '4.DNS',
    :order => 2
  }

attribute 'authoritative_server',
  :description => "authoritative_server",
  :default => "",
  :format => {
    :help => 'Explicit authoritative_server for verification - useful for testing. If not set uses NS records for the zone.',
    :category => '4.DNS',
    :order => 3
  }
