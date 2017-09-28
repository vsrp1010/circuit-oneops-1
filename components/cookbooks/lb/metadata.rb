name             "Lb"
description      "Installs/Configures load balancer"
version          "0.1"
maintainer       "OneOps"
maintainer_email "support@oneops.com"
license          "Apache License, Version 2.0"
depends          "netscaler"
depends          "azure_lb"
depends          "octavia"
depends          "f5-bigip"
depends          "haproxy"

grouping 'default',
  :access => "global",
  :packages => [ 'base', 'mgmt.catalog', 'mgmt.manifest', 'catalog', 'manifest' ]

grouping 'bom',
  :access => "global",
  :packages => [ 'bom' ]

attribute 'listeners',
  :description => "Listeners",
  :data_type => "array",
  :default => "[\"http 80 http 8080\"]",
  :format => {
    :important => true,
    :category => '1.Global',
    :order => 1,
    :pattern => '(http|https|tcp|udp|ssl_bridge|any|terminated_https) (\d+|all|\d+:\/.*?) (http|https|tcp|udp|ssl_bridge|any) (\d+|all)',
    :help => 'Virtual/External protocol and port, then Internal/Compute-Level protocol and port.  4 values space separated: "vprotocol vport iprotocol iport" ex) "https 443 http 8080" or "tcp 5432 tcp 5432" or "terminated_https 443 http 8080"'
  }

attribute 'lbmethod',
  :description => "LB Method",
  :required => "required",
  :default => "roundrobin",
  :format => {
    :important => true,
    :help => 'Select the protocol type',
    :category => '1.Global',
    :order => 2,
    :form => { 'field' => 'select', 'options_for_select' => [['RoundRobin','roundrobin'],['Least Connections','leastconn'],['Source IP Hash','sourceiphash']] }
  }

attribute 'stickiness',
  :description => "Session Persistence",
  :default => 'false',
  :format => {
    :category => '1.Global',
    :help => 'Enable HTTP session persistence',
    :order => 3,
    :form => { 'field' => 'checkbox' }
  }

attribute 'persistence_type',
  :description => "Persistence Type",
  :default => 'cookieinsert',
  :format => {
    :category => '1.Global',
    :help => 'Session persistence type',
    :order => 4,
    :filter => {"all" => {"visible" => "stickiness:eq:true"}},
    :form => { 'field' => 'select', 'options_for_select' => [['SourceIP','sourceip'],['cookieinsert','cookieinsert']] }
  }

attribute 'cookie_domain',
  :description => "Cookie Domain",
  :default => 'default',
  :format => {
    :category => '1.Global',
    :help => 'Cookie Domain - eg walmart.com.',
    :order => 5,
    :filter => {"all" => {"visible" => "stickiness:eq:true"}}
  }

attribute 'enable_lb_group',
  :description => "Enable LB Group",
  :default => 'false',
  :format => {
    :category => '1.Global',
    :help => 'Enable LB Group for persistence across listeners',
    :order => 6,
    :filter => {"all" => {"visible" => "stickiness:eq:true"}},
    :form => { 'field' => 'checkbox' }
  }


attribute 'create_cloud_level_vips',
  :description => "Create cloud vips",
  :required => "required",
  :default => "false",
  :format => {
    :help => 'Create cloud-level vips in addition to dc-level',
    :category => '1.Global',
    :order => 6,
    :form => { 'field' => 'checkbox' }
  }

attribute 'lb_attrs',
  :description => "LB Custom Attrs",
  :default => "{}",
  :data_type => "hash",
  :format => {
    :help => 'LB Custom Attributes',
    :category => '1.Global',
    :order => 7
  }

attribute 'vnames',
  :description => "Virtual Server Names",
  :data_type => "hash",
  :grouping => 'bom',
  :format => {
    :important => true,
    :help => 'Virtual Server Names',
    :category => '1.Global',
    :order => 8
  }

attribute 'dns_record',
  :description => "DNS Record value used by FQDN",
  :grouping => 'bom',
  :format => {
    :important => true,
    :help => 'DNS Record value used by FQDN',
    :category => '1.Global',
    :order => 9
  }

attribute 'availability_zone',
  :description => "Availability Zone",
  :grouping => 'bom',
  :format => {
    :help => 'Availability Zone - used to horizontally scale physical lb devices.',
    :category => '1.Global',
    :order => 10
  }

attribute 'required_availability_zone',
  :description => "Required Availability Zone",
  :default => "",
  :format => {
    :help => 'Required Availability Zone - used to horizontally scale physical lb devices. Leave empty unless instructed to use a specific LB AZ.',
    :category => '1.Global',
    :order => 10
  }

attribute 'connection_limit',
          :description => "Connection Limit",
          :default => "-1",
          :format => {
              :help => 'Applicable only for software loadbalancers. The maximum number of connections per second allowed for the vip. Valid values: a positive integer or -1 for unlimited (default).',
              :category => '1.Global',
    }

attribute 'lb_service_type',
  :description => "LB Service Type",
  :required => "required",
  :default => "lb",
  :format => {
    :important => true,
    :help => 'Select the service type. lb for netscaler; slb for octavia',
    :category => '1.Global',
    :order => 1,
    :form => { 'field' => 'select', 'options_for_select' => [['lb','lb'],['slb','slb']] }
  }

attribute 'ecv_map',
  :description => "ECV",
  :required => "required",
  :default => "{}",
  :data_type => "hash",
  :format => {
    :important => true,
    :help => 'This value will be used in a service monitor. e.g. "80 => GET /taxservice/node". Unused for tcp(s) or udp - those have port-available monitors.',
    :category => '3.Compute Instances',
    :order => 1
  }


attribute 'inames',
  :description => "Servicegroup/Pool Names",
  :data_type => "array",
  :grouping => 'bom',
  :format => {
    :important => true,
    :help => 'Servicegroup/Pool Names',
    :category => '3.Compute Instances',
    :order => 2
  }


attribute 'servicegroup_attrs',
  :description => "Servicegroup Custom Attrs",
  :default => "{}",
  :data_type => "hash",
  :format => {
    :help => 'Servicegroup Custom Attributes',
    :category => '3.Compute Instances',
    :order => 3
  }


recipe "repair", "Repair Lb"
recipe "status", "Lb Status"
recipe "bind_cloud","Bind Cloud"
recipe "unbind_cloud","Unbind Cloud"
