name             'Azuredatadisk'
maintainer       'walmart'
maintainer_email 'kowsalya.palaniappan@walmart.com'
license          'Apache License, Version 2.0'
description      'Installs/Configures azuredatadisk'
version          '0.1.0'
depends          "azure_base"

grouping 'default',
         :access => "global",
         :packages => [ 'base', 'service.storage', 'mgmt.cloud.service', 'cloud.service' ],
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
attribute 'master_rg',
          :description => "Master RG for Storage Account",         
          :required => "required",
          :default => "",
          :format => {
              :help => 'master resource group to hold the storage account',
              :category => '2.Config',
              :order => 1
          }
attribute 'storage_account_std',
          :description => "Azure Standard Storage Account Name",       
          :required => "required",
          :default => "",
          :format => {
              :help => 'standard storage account name',
              :category => '2.Config',
              :order => 2
          }

attribute 'storage_account_prm',
          :description => "Azure Premium Storage Account Name",       
          :required => "required",
          :default => "",
          :format => {
              :help => 'premium storage account name',
              :category => '2.Config',
              :order => 2
          }

attribute 'region',
          :description => "Location",
          :default => "South Central US",
          :format => {
              :help => 'Use the location string',
              :category => '2.Config',
              :order => 3,
              :form => { 'field' => 'select', 'options_for_select' => [
                  ['Central US','centralus'],
                  ['East US','eastus'],
                  ['East US 2','eastus2'],
                  ['North Central US','northcentralus'],
                  ['South Central US','southcentralus'],
                  ['West US','westus'],
                  ['Japan East','japaneast'],
                  ['East Asia','eastasia'],
                  ['UK West','ukwest'],
                  ['UK South','uksouth']
              ]
              }
          }

