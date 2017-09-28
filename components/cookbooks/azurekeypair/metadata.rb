name 'Azure Keypair'
description 'General purpose key pairs'
version '0.1'
maintainer 'OneOps, Inc.'
maintainer_email 'support@oneops.com'
license 'Apache License, Version 2.0'

depends 'azure_base'

grouping 'default',
         :access => "global",
         :packages => [ 'base', 'account', 'mgmt.catalog', 'mgmt.manifest', 'catalog', 'manifest' ]

grouping 'bom',
         :access => "global",
         :packages => [ 'bom' ]


attribute 'key_name',
          :description => "Key Name",
          :grouping => 'bom',
          :data_type => "text",
          :format => {
              :help => 'Key-Name value pair',
              :category => '1.Global',
              :order => 6
          }