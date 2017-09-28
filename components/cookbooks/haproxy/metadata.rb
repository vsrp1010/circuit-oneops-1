name             "Haproxy"
description      "HA Proxy"
version          "0.1"
maintainer       "OneOps"
maintainer_email "support@oneops.com"
license          "Apache License, Version 2.0"

grouping 'default',
  :access => "global",
  :packages => [ 'base']

grouping 'instance',
  :access => "global",
  :packages => [ 'mgmt.catalog', 'mgmt.manifest', 'catalog', 'manifest', 'bom' ]

grouping 'service',
  :access => "global",
  :packages => [ 'service.lb', 'mgmt.cloud.service', 'cloud.service' ]

    
# attrs for cloud service
attribute 'endpoint',
  :grouping => 'service',
  :description => "endpoint",
  :required => "required",
  :format => {
    :important => true,
    :help => 'Endpoint of haproxy',
    :category => '1.General',
    :order => 1
  }    
  

attribute 'username',
  :grouping => 'service',
  :description => "username",
  :required => "required",
  :format => {
    :important => true,
    :help => 'Username',
    :category => '1.General',
    :order => 3
  }      

attribute 'password',
  :grouping => 'service',
  :description => "password",
  :encrypted => true, 
  :required => "required",
  :format => {
    :help => 'Password',
    :category => '1.General',
    :order => 4
  }        
    

attribute 'enable_stats_socket',
  :grouping => 'instance',  
  :description => "Enable Stats Socket",
  :required => "required",
  :default => 'true',
  :format => {
    :help => 'Enable stats socket for monitoring',
    :category => '2.Stats',
    :form => { 'field' => 'checkbox' },
    :order => 1
  }

attribute 'stats_socket_location',
  :grouping => 'instance', 
  :description => "Stats Socket Location",
  :required => "required",
  :default => '/var/lib/haproxy/stats',
  :format => {
    :help => 'Stats Socket Location',
    :category => '2.Stats',
    :order => 2
  }

attribute 'enable_stats_web',
  :grouping => 'instance', 
  :description => "Enable Stats Web",
  :required => "required",
  :default => 'true',
  :format => {
    :help => 'Enable stats web monitoring',
    :category => '2.Stats',
    :form => { 'field' => 'checkbox' },
    :order => 3
  }

attribute 'stats_web_port',
  :grouping => 'instance',
  :description => "Stats Web Port",
  :required => "required",
  :default => '1936',
  :format => {
    :help => 'Stats Web port',
    :category => '2.Stats',
    :order => 4
  }
  
  
attribute 'lbmethod',
  :grouping => 'instance',
  :description => "LB Method",
  :required => "required",
  :default => "leastconn",
  :format => {
    :important => true,
    :help => 'Select the loadbalance method',
    :category => '1.Config',
    :order => 1,
    :form => { 'field' => 'select', 'options_for_select' => [['Least Connections','leastconn'],['RoundRobin','roundrobin']] }
  }

attribute 'lbmode',
  :grouping => 'instance',
  :description => "LB Mode",
  :required => "required",
  :default => "tcp",
  :format => {
    :important => true,
    :help => 'Select the loadbalance method',
    :category => '1.Config',
    :order => 2,
    :form => { 'field' => 'select', 'options_for_select' => [['TCP','tcp'],['HTTP','http']] }
  }
      
attribute 'listeners',
  :grouping => 'instance',
  :description => "Map of External to Internal Ports",
  :required => "required",  
  :default => "{}",
  :data_type => "hash",
  :format => {
    :important => true,
    :help => 'Map of External to Internal Ports - uses RequiresCompute payload for internal server list. Make sure they are not the same.',
    :category => '1.Config',
    :order => 3
  }   
    
attribute 'timeout_connect',
  :grouping => 'instance',
  :description => "Timeout Connect",
  :required => "required",
  :default => "500s",
  :format => {
    :help => 'Timeout Connect',
    :category => '1.Config',
    :order => 4
  }

attribute 'timeout_client',
  :grouping => 'instance',
  :description => "Timeout Client",
  :required => "required",
  :default => "5000s",
  :format => {
    :help => 'Timeout Client',
    :category => '1.Config',
    :order => 5
  }

attribute 'timeout_server',
  :grouping => 'instance',
  :description => "Timeout Server",
  :required => "required",
  :default => "1h",
  :format => {
    :help => 'Timeout Server',
    :category => '1.Config',
    :order => 6
  }

attribute 'maxconn_defaults',
  :grouping => 'instance',
  :description => "Max Connections Defaults",
  :required => "required",
  :default => "32000",
  :format => {
    :help => 'Max Connections Global',
    :category => '1.Config',
    :order => 7
  }

attribute 'maxconn_server',
  :grouping => 'instance',
  :description => "Max Connections Per Server",
  :required => "required",
  :default => "1500",
  :format => {
    :help => 'Max Connections Per Server',
    :category => '1.Config',
    :order => 8
  } 
  
attribute 'retries',
  :grouping => 'instance',
  :description => "Retries",
  :required => "required",
  :default => "3",
  :format => {
    :help => 'Retries',
    :category => '1.Config',
    :order => 9
  }         

attribute 'options',
  :grouping => 'instance',
  :description => "Options",
  :required => "required",
  :default => '["dontlognull","redispatch"]',
  :data_type => "array",
  :format => {
    :help => 'Options',
    :category => '1.Config',
    :order => 10
  }         
  
attribute 'check_port',
   :grouping => 'instance',
   :description => "Check Port",
   :default => "",
   :format => {
   :help => 'Handshake check',
   :category => '1.Config',
   :order => 11
  }

    
attribute 'override_config',
  :grouping => 'instance',
  :description => "Override Config Content",
  :data_type => "text",
  :format => {
    :help => 'Will use this config or if empty generate config based on members',
    :category => '1.Config',
    :order => 20
  }
  
recipe "status", "Haproxy Status"
recipe "start", "Start Haproxy"
recipe "stop", "Stop Haproxy"
recipe "restart", "Restart Haproxy"
recipe "repair", "Repair Haproxy"
