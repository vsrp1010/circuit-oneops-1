name "Os"
description "Installs/Configures OperatingSystem"
maintainer "OneOps"
maintainer_email "support@oneops.com"
license "Apache License, Version 2.0"
depends "shared"
depends "simple_iptables"
depends 'security'

grouping 'default',
         :access   => "global",
         :packages => ['base', 'mgmt.catalog', 'mgmt.manifest', 'catalog']

grouping 'bom',
         :access   => "global",
         :packages => ['bom']

grouping 'manifest',
         :access   => "global",
         :packages => ['manifest']


# identity
attribute 'hostname',
          :description => "Hostname",
          :grouping    => 'bom',
          :format      => {
            :help      => 'Hostname composite of ciName + ciId',
            :category  => '1.Identity',
            :important => true,
            :order     => 1
          }

attribute 'tags',
          :description => "tags",
          :grouping    => 'bom',
          :data_type   => "hash",
          :default     => "{}",
          :format      => {
            :help     => 'Tags',
            :category => '1.Identity',
            :order    => 2
          }


attribute 'ostype',
  :description => "OS Type",
  :required => "required",
  :default => "centos-7.2",
  :format => {
    :important => true,
    :help => 'OS types are mapped to the correct cloud provider OS images - see cloud ostype when this value is default-cloud',
    :category => '3.Operating System',
    :order => 1,
    :form => { 'field' => 'select', 'options_for_select' => [
      ['Ubuntu 16.04','ubuntu-16.04'],
      ['Ubuntu 14.04','ubuntu-14.04'],
      ['CentOS 7.0','centos-7.0'],
      ['CentOS 7.2','centos-7.2'],
      ['CentOS 7.3','centos-7.3'],
      ['CentOS-LXD 7.2','centos-lxd-7.2'],
      ['CentOS-LXD 7.3','centos-lxd-7.3'],
      ['Redhat 7.0','redhat-7.0'],
      ['Redhat 7.2','redhat-7.2'],
      ['Redhat 7.3','redhat-7.3'],
      ['Windows 2012 R2','windows_2012_r2'],
      ['Windows 2016','windows_2016']
    ] }
  }


attribute 'image_id',
          :description => "OS Image",
          :format      => {
            :help     => 'Custom machine image id (overwrites the OS type selection)',
            :category => '3.Operating System',
            :order    => 2
          }

attribute 'osname',
          :description => "OS Name",
          :grouping    => 'bom',
          :format      => {
            :important => true,
            :help      => 'Operating System value reported by uname -a',
            :category  => '3.Operating System',
            :order     => 3
          }

attribute 'features',
          :description => 'Windows Features',
          :data_type   => 'array',
          :default     => '[]',
          :format      => {
            :help     => 'Install additional windows features',
            :category => '3.Operating System',
            :filter   => {'all' => {'visible' => 'ostype:eq:windows_2012_r2 || ostype:eq:windows_2016'}},
            :order    => 4
          }

attribute 'repo_list',
          :description => "OS Package Repositories",
          :data_type   => "array",
          :format      => {
            :help     => 'List of repositories add commands - ex) yum-config-manager --add-repo repository_url or deb http://us.archive.ubuntu.com/ubuntu/ hardy main restricted ',
            :category => '3.Operating System',
            :filter   => {'all' => {'visible' => 'ostype:neq:windows_2012_r2 && ostype:neq:windows_2016'}},
            :order    => 6
          }


# networking
attribute 'hosts',
          :description => "Additional /etc/hosts",
          :data_type   => "hash",
          :default     => "{}",
          :format      => {
            :help     => 'First field is hostname, second is IP address',
            :category => '4.Networking',
            :filter   => {'all' => {'visible' => 'ostype:neq:windows_2012_r2 && ostype:neq:windows_2016'}},
            :order    => 1
          }


attribute 'additional_search_domains',
          :description => "Additional search domains",
          :data_type   => "array",
          :default     => '[]',
          :format      => {
            :help     => 'Additional search domains added to dhclient.conf for resolv.conf',
            :category => '4.Networking',
            :filter   => {'all' => {'visible' => 'ostype:neq:windows_2012_r2 && ostype:neq:windows_2016'}},
            :order    => 7
          }

attribute 'proxy_map',
          :description => "Proxy Map",
          :data_type   => "hash",
          :default     => '{}',
          :format      => {
            :help     => 'Map of proxies - ex) http => http://yourproxy, https => https://yourhttpsproxy, etc',
            :category => '4.Networking',
            :filter   => {'all' => {'visible' => 'ostype:neq:windows_2012_r2 && ostype:neq:windows_2016'}},
            :order    => 8
          }

attribute 'dhclient',
          :description => "Keep long running dhclient after boot (not recommended if dhcp server issues)",
          :default     => 'false',
          :format      => {
            :help     => 'When selected enables long running dhclient which will manage periodic IP Address renewals. When not selected, dhclient will be stopped and IP Address will behave as if static.',
            :category => '4.Networking',
            :form     => {'field' => 'checkbox'},
            :filter   => {'all' => {'visible' => 'ostype:neq:windows_2012_r2 && ostype:neq:windows_2016'}},
            :order    => 9
          }

# firewall
attribute 'iptables_enabled',
          :description => "Enable Firewall",
          :default     => 'false',
          :format      => {
            :help     => 'Disable / Enable Firewall',
            :category => '5.Firewall',
            :form     => {'field' => 'checkbox'},
            :filter   => {'all' => {'visible' => 'ostype:neq:windows_2012_r2 && ostype:neq:windows_2016'}},
            :order    => 1
          }

attribute 'drop_policy',
          :description => "Drop Policy",
          :default     => 'true',
          :format      => {
            :help     => 'Default Policy to DROP',
            :category => '5.Firewall',
            :form     => {'field' => 'checkbox'},
            :filter   => {'all' => {'visible' => 'iptables_enabled:eq:true'}},
            :order    => 2
          }

attribute 'allow_loopback',
          :description => "Allow Loopback",
          :default     => 'true',
          :format      => {
            :help     => 'Allow all traffic on the loopback device',
            :category => '5.Firewall',
            :form     => {'field' => 'checkbox'},
            :filter   => {'all' => {'visible' => 'iptables_enabled:eq:true'}},
            :order    => 3
          }

attribute 'allow_rules',
          :description => "Allow rules",
          :data_type   => "array",
          :default     => '["-p tcp --dport 22"]',
          :format      => {
            :help     => 'Allow rules. e.g. \"-p tcp --dport 80 -m limit --limit 25/minute --limit-burst 100\"',
            :category => '5.Firewall',
            :filter   => {'all' => {'visible' => 'iptables_enabled:eq:true'}},
            :order    => 4
          }

attribute 'deny_rules',
          :description => "Deny rules",
          :data_type   => "array",
          :default     => '[]',
          :format      => {
            :help     => 'Deny rules. e.g. \"-p tcp --dport 21\"',
            :category => '5.Firewall',
            :filter   => {'all' => {'visible' => 'iptables_enabled:eq:true'}},
            :order    => 5
          }

attribute 'nat_rules',
          :description => "NAT rules",
          :data_type   => "array",
          :default     => '[]',
          :format      => {
            :help     => 'NAT rules. e.g. \"--protocol tcp --dport 80 --jump REDIRECT --to-port 8080\"',
            :category => '5.Firewall',
            :filter   => {'all' => {'visible' => 'iptables_enabled:eq:true'}},
            :order    => 6
          }

# time
attribute 'timezone',
          :description => "Timezone",
          :default     => 'UTC',
          :format      => {
            :help     => 'System time zone',
            :category => '6.Time',
            :order    => 1
          }

# security
attribute 'limits',
          :description => "limits.conf",
          :data_type   => "hash",
          :default     => '{}',
          :format      => {
            :help     => 'Key value pairs for limits.conf system settings. Ex: "nofile = 512".Domain is "*" and types are "hard and soft"',
            :category => '7.Security',
            :filter   => {'all' => {'visible' => 'ostype:neq:windows_2012_r2 && ostype:neq:windows_2016'}},
            :order    => 1
          }

attribute 'sshd_config',
          :description => "Custom sshd_config",
          :data_type   => "hash",
          :default     => '{"Ciphers":"aes128-ctr,aes192-ctr,aes256-ctr,arcfour256,arcfour128,arcfour","Macs":"hmac-sha1,hmac-ripemd160"}',
          :format      => {
            :help     => 'Custom entries for /etc/ssh/sshd_config',
            :category => '7.Security',
            :filter   => {'all' => {'visible' => 'ostype:neq:windows_2012_r2 && ostype:neq:windows_2016'}},
            :order    => 2
          }

attribute 'applied_compliance',
          :description => 'Applied Compliances',
          :data_type   => 'hash',
          :default     => '{}',
          :format      => {
            :help     => 'A map of last applied versions of compliances.',
            :category => '7.Security',
            :filter   => {'all' => {'visible' => 'ostype:neq:windows_2012_r2 && ostype:neq:windows_2016'}},
            :order    => 3
          }


# kernel
attribute 'sysctl',
          :description => "sysctl.conf",
          :data_type   => "hash",
          :default     => '{}',
          :format      => {
            :help     => 'Key Value pairs for sysctl.conf kernel system settings. Ex: "fs.file-max = 65535"',
            :category => '8.Kernel',
            :filter   => {'all' => {'visible' => 'ostype:neq:windows_2012_r2 && ostype:neq:windows_2016'}},
            :order    => 1
          }

# Env variables
attribute 'env_vars',
          :description => 'System Env Vars',
          :data_type   => 'hash',
          :default     => '{}',
          :format      => {
            :help     => 'Key Value pairs for system env variables (Ex: "LANG = en_US.UTF-8"). Here you can also refer CLOUD, GLOBAL and LOCAL variables as env value.',
            :category => '9.Environment Variables',
            :filter   => {'all' => {'visible' => 'ostype:neq:windows_2012_r2 && ostype:neq:windows_2016'}},
            :order    => 1
          }

attribute 'pam_groupdn',
          :description => "PAM Filter",
          :data_type   => "text",
          :format      => {
            :help     => 'List of groups need access to SSH. Format (memberOf=group_dn1)(memberOf=group_dn2)...',
            :category => '9.LDAP Configuration',
            :filter   => {'all' => {'visible' => 'ostype:neq:windows_2012_r2 && ostype:neq:windows_2016'}},
            :order    => 1
          }

recipe "repair", "Repair"
recipe "upgrade-os-all", "Upgrade OS Packages"
recipe "upgrade-os-security", "Upgrade OS Security Packages Only"

recipe "upgrade-os-package",
       :description => 'upgrading a specific package',
       :args        => {
         "path" => {
           "name"         => "package",
           "description"  => "package name",
           "defaultValue" => "",
           "required"     => true,
           "dataType"     => "string"
         }
       }

recipe 'apply-security-compliance',
       :description => 'apply security requirements configured by cloud compliance',
       :args        => {
         'compliance' => {
           :name => 'name',
           :description => 'Compliance name to apply, use "*" to apply all compliances, use "," to apply multiple compliances',
           :defaultValue => '*',
           :required => true,
           :dataType => 'string'
         },
         'version' => {
           :name => 'version',
           :description => 'Compliance version to apply, use "LATEST" to apply latest versions.',
           :defaultValue => 'LATEST',
           :required => false,
           :dataType => 'string'
         }
       }

recipe 'reconfig-network', "Reconfig Network"
