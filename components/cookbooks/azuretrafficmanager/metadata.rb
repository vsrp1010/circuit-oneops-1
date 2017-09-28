name             'Azuretrafficmanager'
description      'Installs/Configures trafficmanager'
version          '0.1.0'
maintainer       'OneOps'
maintainer_email 'support@oneops.com'
license          'Apache License, Version 2.0'

grouping 'default',
         :access => "global",
         :packages => [ 'base', 'mgmt.catalog', 'catalog', 'mgmt.manifest', 'manifest', 'bom', 'mgmt.cloud.service', 'cloud.service' ],
         :namespace => true

attribute 'traffic-routing-method',
          :description => "Traffic Routing Method",
          :default => '{"Performance"}',
          :format => {
              :help => 'The traffic routing method for the profile',
              :category => '2.Config',
              :order => 1,
              :form => { 'field' => 'select', 'options_for_select' => [
                  ['Performance','Performance'],
                  ['Weighted','Weighted'],
                  ['Priority','Priority']]
              }
          }

attribute 'ttl',
          :description => "DNS Time-to-Live Cache",
          :required => "required",
          :default => "30",
          :format => {
              :help => 'Time to live',
              :category => '2.Config',
              :order => 2,
              :pattern => '^(3[0-9]|[4-9][0-9]|[0-9][0-9][0-9]|[0-9],[0-9][0-9][0-9]|[0-9][0-9],[0-9][0-9][0-9]|[0-9][0-9][0-9],[0-9][0-9][0-9])$'
          }

attribute 'location',
          :description => "Location",
          :default => "South Central US",
          :format => {
              :help => 'Use the location string',
              :category => '2.Config',
              :order => 3,
              :form => { 'field' => 'select', 'options_for_select' => [
                  ['South Central US','southcentralus'],
                  ['Central US','centralus'],
                  ['North Central US','northcentralus'],
                  ['East US 2','eastus2'],
                  ['West US','westus'],
                  ['East US','eastus']]
              }
          }
