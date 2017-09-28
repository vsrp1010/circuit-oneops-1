name             'Azure_base'
maintainer       'OneOps'
maintainer_email 'support@oneops.com'
license          'Apache License, Version 2.0'
description      'Provides basic Azure facilities for OneOps.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

grouping 'default',
         :access => "global",
         :packages => [ 'base', 'mgmt.cloud.service', 'cloud.service' ],
         :namespace => true
