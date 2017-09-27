name             "fqdn"
description      "Updates FQDN records"
version          "0.1"
maintainer       "OneOps"
maintainer_email "support@oneops.com"
license          "Copyright OneOps, All rights reserved."
depends          "netscaler"
depends          "azuredns"

grouping 'default',
  :access => "global",
  :packages => [ 'base', 'mgmt.catalog', 'mgmt.manifest', 'catalog', 'manifest' ]

grouping 'bom',
  :access => "global",
  :packages => [ 'bom' ]

attribute 'aliases',
  :description => "Short CNAME aliases",
  :data_type => "array",
  :format => {
    :help => 'List of additional short-name aliases to be configured in the DNS service (Note: the FQDN record of these CNAME aliases will include the environment subdomain)',
    :category => '1.Global',
    :pattern => '[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])',
    :order => 1
  }

attribute 'full_aliases',
  :description => "Full CNAME aliases",
  :data_type => "array",
  :format => {
    :help => 'List of additional full-domain name aliases to be configured in the DNS service (Note: the FQDN record of these CNAME aliases will *not* include the environment subdomain)',
    :category => '1.Global',
    :pattern => '([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])',
    :order => 2
  }

attribute 'hijackable_full_aliases',
  :description => "Hijackable Full CNAME",
  :required => true,
  :default => "false",
  :format => {
    :help => 'Enable/Check this to create TXT record allowing deletion of an unknown value. Use with caution: a dev env with same cname as prod would hijack it if the prod env had this flag enabled.',
    :category => '1.Global',
    :form => { 'field' => 'checkbox' },
    :order => 3
  }  
  
attribute 'ttl',
  :description => "Time to Live",
  :default => '60',
  :format => {
    :help => 'DNS entries',
    :category => '1.Global',
    :order => 4
  }


attribute 'ptr_enabled',
  :description => "PTR Record",
  :required => true,
  :default => "false",
  :format => {
    :help => 'Enable/Check this to create PTR record from ip to dns name from PTR Source attribute.',
    :category => '1.Global',
    :form => { 'field' => 'checkbox' },
    :order => 5
  }

attribute 'ptr_source',
  :description => "PTR Source",
  :required => true,
  :default => 'platform',
  :format => {
    :help => 'The source of the ptr name. Instance would get from the A-Record name. Platform would use the platform-level name.',
    :category => '1.Global',
    :order => 6,
    :form => { 'field' => 'select', 'options_for_select' => [
      ['Instance','instance'],
      ['Platform','platform']
      ] }
  }

attribute 'entries',
  :description => "DNS entries",
  :grouping => 'bom',
  :data_type => "hash",
  :format => {
    :important => true,
    :help => 'DNS entries',
    :category => '1.Global',
    :order => 7
  }

attribute 'distribution',
  :description => "GDNS LB method",
  :required => true,
  :default => 'proximity',
  :format => {
    :help => 'DNS distribution / GSLB lbmethod',
    :category => '1.Global',
    :order => 8,
    :form => { 'field' => 'select', 'options_for_select' => [
      ['Proximity','proximity'],
      ['Latency','latency'],
      ['RoundRobin','roundrobin']] }
  }


attribute 'gslb_vnames',
  :description => "GSLB vnames",
  :grouping => 'bom',
  :default => '{}',
  :data_type => "hash",
  :format => {
    :help => 'GSLB vserver name to domain map',
    :category => '1.Global',
    :order => 9
  }

  
recipe "repair", "Repair"
recipe "gslbstatus", "GSLB Status"
