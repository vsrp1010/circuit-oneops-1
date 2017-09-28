name             "Netscaler"
description      "Netscaler"
version          "0.1"
maintainer       "OneOps"
maintainer_email "support@oneops.com"
license          "Apache License, Version 2.0"

grouping 'default',
  :access => "global",
  :packages => [ 'base', 'mgmt.catalog', 'catalog', 'mgmt.manifest', 'manifest', 'bom', 'mgmt.cloud.service', 'cloud.service' ],
  :namespace => true
  
attribute 'host',
  :description => "Netscaler Host",
  :required => "required",
  :format => { 
    :category => '1.Global', 
    :order => 1, 
    :help => 'Netscaler host fqdn or ip'
  }
  
attribute 'username',
  :description => "Netscaler Username",
  :required => "required",
  :format => { 
    :category => '1.Global', 
    :order => 2, 
    :help => 'Netscaler rest api username'
  }

attribute 'password',
  :description => "Netscaler Password",
  :required => "required",
  :encrypted => true,
  :format => { 
    :category => '1.Global', 
    :order => 3, 
    :help => 'Netscaler rest api username'
  }

attribute 'ip_range',
  :description => "IP range for LB Vservers",
  :required => "required",
  :format => { 
    :category => '1.Global', 
    :order => 4, 
    :help => 'IP range for LB Vservers - ex) 10.0.0.1/24'
  }

attribute 'gslb_site',
  :description => "GSLB Site",
  :format => { 
    :category => '1.Global', 
    :order => 5 , 
    :help => 'GSLB Site'
  }

attribute 'gslb_base_domain',
  :description => "GSLB Base Domain",
  :default => '',
  :format => { 
    :category => '1.Global', 
    :order => 6, 
    :help => 'GSLB Base Domain'
  }

attribute 'gslb_site_dns_id',
  :description => "GSLB Site DNS id",
  :default => '',
  :format => { 
    :category => '1.Global', 
    :order => 7, 
    :help => 'GSLB Site DNS id'
  }

attribute 'gslb_authoritative_servers',
  :description => "GSLB Authoritative DNS Servers",
  :data_type => "array",
  :default => '[]',
  :format => { 
    :category => '1.Global', 
    :order => 8, 
    :help => 'GSLB/Authoritative DNS Servers'
  }

attribute 'availability_zones',
  :description => "Map of AZ to netscaler",
  :data_type => "hash",
  :default => '{}',
  :required => "required",
  :format => { 
    :category => '1.Global', 
    :order => 9, 
    :help => 'Users can have their vip/lb in one or more AZ, by default existing netscaler host is mapped to AZ1'
  }

attribute 'az_ip_range_map',
  :description => "Map of AZ to vip CIDR",
  :data_type => "hash",
  :default => '{}',
  :required => "required",
  :format => { 
    :category => '1.Global', 
    :order => 10, 
    :help => 'Map of AZ to vip CIDR'
  }

attribute 'active_az_list',
  :description => "Active AZ List",
  :data_type => "array",
  :default => '[]',
  :required => "required",
  :format => { 
    :category => '1.Global', 
    :order => 11, 
    :help => 'Active AZ list to schedule new / replaced LB'
  }    

recipe "status", "Netscaler Status"
