name 'Azuregateway'
description 'Azure Application Gateway'
version '0.1.0'
maintainer 'OneOps'
maintainer_email 'support@oneops.com'
license 'Apache License, Version 2.0'

grouping 'default',
         :access => "global",
         :packages => ['base', 'mgmt.catalog', 'catalog', 'mgmt.manifest', 'manifest', 'bom', 'mgmt.cloud.service', 'cloud.service'],
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
              :form => {'field' => 'select', 'options_for_select' => [
                  ['Central US', 'centralus'],
                  ['East US', 'eastus'],
                  ['East US 2', 'eastus2'],
                  ['North Central US', 'northcentralus'],
                  ['South Central US', 'southcentralus'],
                  ['West US', 'westus']
              ]
              }
          }

attribute 'gateway_size',
          :description => "Gateway Size",
          :default => "Medium",
          :format => {
              :help => 'Use gateway size',
              :category => '2.Config',
              :order => 6,
              :form => {'field' => 'select', 'options_for_select' => [
                  ['Small', 'small'],
                  ['Medium', 'medium'],
                  ['Large', 'large']
              ]
              }
          }

attribute 'express_route_enabled',
          :description => "Express Route",
          :default => "false",
          :format => {
              :help => 'An Azure ExpressRoute is a private connections between Azure datacenters and your on-premise infrastructure. ExpressRoute connections do not go over the public Internet.',
              :category => '3.Network Section',
              :order => 7,
              :form => {'field' => 'checkbox'}
          }

attribute 'resource_group',
          :description => "Network Resource Group",
          :default => '',
          :format => {
              :help => 'Mandatory only for private (corporate address space, eg - express route), Fill this with master resource group name which has Predefined Private VNets.',
              :category => '3.Network Section',
              :order => 8,
              :filter => {'all' => {'visible' => 'express_route_enabled:eq:true'}}
          }

attribute 'network',
          :description => "Virtual Network Name",
          :default => '',
          :format => {
              :help => 'Mandatory only for private (corporate address space, eg - express route), Fill this with Predefined Private VNET and subnet (in the field below)name to use.Optional for public ip type,if empty new VNet and subnet will be created',
              :category => '3.Network Section',
              :order => 9,
              :filter => {'all' => {'visible' => 'express_route_enabled:eq:true'}}
          }

attribute 'network_address',
          :description => "Network Address Range",
          :default => '',
          :format => {
              :help => 'One address space in CIDR notation must be added.',
              :category => '3.Network Section',
              :order => 10,
              :filter => {'all' => {'visible' => 'express_route_enabled:eq:false'}}
          }

attribute 'subnet_address',
          :description => "Subnet Address Range",
          :default => '',
          :format => {
              :help => 'Many comma delimited subnet address ranges in CIDR notation may be added.',
              :category => '3.Network Section',
              :order => 11,
              :filter => {'all' => {'visible' => 'express_route_enabled:eq:false'}}
          }

attribute 'gateway_subnet_address',
          :description => "Gateway Subnet Address Range",
          :default => '',
          :format => {
              :help => 'Add a single subnet address in CIDR notation.',
              :category => '3.Network Section',
              :order => 12,
              :filter => {'all' => {'visible' => 'express_route_enabled:eq:false'}}
          }

attribute 'cookies_enabled',
          :description => "Enable Cookies",
          :default => "false",
          :format => {
              :help => 'Enable cookie to ensure that request from a client session is always directed to the same web server. Cookies should be enable in case of SSL offload.',
              :category => '3.Network Section',
              :order => 13,
              :form => {'field' => 'checkbox'}
          }
