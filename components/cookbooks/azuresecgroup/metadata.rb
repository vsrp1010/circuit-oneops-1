name 'azuresecgroup'
description 'Security group for Azure'
version '0.1'
maintainer 'OneOps, Inc.'
maintainer_email 'support@oneops.com'
license 'Apache License, Version 2.0'
depends 'azure'

grouping 'default',
         :access => "global",
         :packages => [ 'base', 'account', 'mgmt.catalog', 'mgmt.manifest', 'catalog', 'manifest' ]

grouping 'bom',
         :access => "global",
         :packages => [ 'bom' ]