name             "Compute"
description      "Installs/Configures compute"
maintainer       "OneOps"
maintainer_email "support@oneops.com"
license          "Apache License, Version 2.0"
depends          "azure"
depends          "shared"
depends          "fqdn"

grouping 'default',
  :access => "global",
  :packages => [ 'base', 'mgmt.catalog', 'mgmt.manifest', 'catalog']

grouping 'bom',
  :access => "global",
  :packages => [ 'bom' ]

grouping 'manifest',
  :access => "global",
  :packages => [ 'manifest' ]


# identity
attribute 'instance_name',
  :description => "Instance Name",
  :grouping => 'bom',
  :format => {
    :help => 'Name given to the compute within the cloud provider',
    :important => true,
    :category => '1.Identity',
    :order => 2
  }

attribute 'instance_id',
  :description => "Instance Id",
  :grouping => 'bom',
  :format => {
    :important => true,
    :help => 'Unique Id of the compute instance within the cloud provider',
    :category => '1.Identity',
    :order => 3
  }

attribute 'host_id',
  :description => "Host Id",
  :grouping => 'bom',
  :format => {
    :help => 'Host Id to identify hypervisor / compute node',
    :category => '1.Identity',
    :order => 4
  }

attribute 'hypervisor',
  :description => "Hypervisor",
  :grouping => 'bom',
  :format => {
    :important => true,
    :help => 'Hypervisor identifier.May require admin credentials.',
    :category => '1.Identity',
    :order => 5
  }

attribute 'availability_zone',
  :description => "Availability Zone",
  :grouping => 'bom',
  :format => {
    :important => true,
    :help => 'Assigned Availability Zone',
    :category => '1.Identity',
    :order => 6
  }

attribute 'required_availability_zone',
  :description => "Required Availability Zone",
  :grouping => 'manifest',
  :default => '',
  :format => {
    :help => 'Required Availability Zone - for override of round-robin or random az assignment',
    :category => '1.Identity',
    :order => 7
  }

attribute 'metadata',
  :description => "metadata",
  :grouping => 'bom',
  :data_type => "hash",
  :default => "{}",
  :format => {
    :help => 'Key Value pairs of VM metadata from vm/iaas using fog server.metadata',
    :category => '1.Identity',
    :order => 8
  }

attribute 'tags',
  :description => "tags",
  :grouping => 'bom',
  :data_type => "hash",
  :default => "{}",
  :format => {
    :help => 'Tags',
    :category => '1.Identity',
    :order => 9
  }


# state

attribute 'instance_state',
  :description => "Instance State",
  :grouping => 'bom',
  :format => {
    :help => 'Instance status value returned by Cloud Provider. i.e. Fog::Compute::OpenStack::Server.state',
    :category => '2.State',
    :order => 1
  }

attribute 'task_state',
  :description => "Task State",
  :grouping => 'bom',
  :format => {
    :help => 'Task state value returned by Cloud Provider. i.e. os_ext_sts_task_state',
    :category => '2.State',
    :order => 2
  }

attribute 'vm_state',
  :description => "VM State",
  :grouping => 'bom',
  :format => {
    :help => 'VM state value returned by Cloud Provider. i.e. os_ext_sts_vm_state',
    :category => '2.State',
    :order => 3
  }



# resources
attribute 'size',
  :description => "Instance Size",
  :required => "required",
  :default => 'S',
  :format => {
    :help => 'Compute instance sizes are mapped against instance types offered by cloud providers - see provider documentation for details',
    :category => '2.Resources',
    :order => 1,
    :form => { 'field' => 'select', 'options_for_select' => [
          ['XS (Micro)','XS'],
          ['S (Standard)','S'],
          ['M (Standard)','M'],
          ['L (Standard)','L'],
          ['XL (Standard)','XL'],
          ['XXL (Standard)','XXL'],
          ['3XL (Standard)','3XL'],
          ['4XL (Standard)','4XL'],
          ['L-BD (Big Data Optimized)','L-BD'],
          ['XL-BD (Big Data Optimized)','XL-BD'],
          ['L-NoSQL (NoSQL Flavor)','L-NoSQL'],
          ['XL-NoSQL (NoSQL Flavor)','XL-NoSQL'],
          ['L-LXD (LXD)','L-LXD'],
          ['L-IO-LXD (LXD)','L-IO-LXD'],
          ['XL-IO-LXD (LXD)','XL-IO-LXD'],
          ['XXL-IO-LXD (LXD)','XXL-IO-LXD'],
          ['S-MEM-LXD (LXD)','S-MEM-LXD'],
          ['L-MEM-LXD (LXD)','L-MEM-LXD'],
          ['BM-V1-56 (Standard Baremetal)','BM-V1-56'],
          ['S-Win (Windows)','S-WIN'],
          ['M-Win (Windows)','M-WIN'],
          ['L-Win (Windows)','L-WIN'],
          ['XL-Win (Windows)','XL-WIN'],
          ['XL-Win-LDO (Windows Local Drive Optimized)','XL-WIN-LDO'],
          ['S-CPU (Compute Optimized)','S-CPU'],
          ['M-CPU (Compute Optimized)','M-CPU'],
          ['L-CPU (Compute Optimized)','L-CPU'],
          ['XL-CPU (Compute Optimized)','XL-CPU'],
          ['XXL-CPU (Compute Optimized)','XXL-CPU'],
          ['3XL-CPU (Compute Optimized)','3XL-CPU'],
          ['4XL-CPU (Compute Optimized)','4XL-CPU'],
          ['5XL-CPU (Compute Optimized)','5XL-CPU'],
          ['6XL-CPU (Compute Optimized)','6XL-CPU'],
          ['7XL-CPU (Compute Optimized)','7XL-CPU'],
          ['8XL-CPU (Compute Optimized)','8XL-CPU'],
          ['9XL-CPU (Compute Optimized)','9XL-CPU'],
          ['10XL-CPU (Compute Optimized)','10XL-CPU'],
          ['11XL-CPU (Compute Optimized)','11XL-CPU'],
          ['S-MEM (Memory Optimized)','S-MEM'],
          ['M-MEM (Memory Optimized)','M-MEM'],
          ['L-MEM (Memory Optimized)','L-MEM'],
          ['XL-MEM (Memory Optimized)','XL-MEM'],
          ['XXL-MEM (Memory Optimized)','XXL-MEM'],
          ['3XL-MEM (Memory Optimized)','3XL-MEM'],
          ['4XL-MEM (Memory Optimized)','4XL-MEM'],
          ['5XL-MEM (Compute Optimized)','5XL-MEM'],
          ['6XL-MEM (Compute Optimized)','6XL-MEM'],
          ['7XL-MEM (Compute Optimized)','7XL-MEM'],
          ['8XL-MEM (Compute Optimized)','8XL-MEM'],
          ['9XL-MEM (Compute Optimized)','9XL-MEM'],
          ['10XL-MEM (Compute Optimized)','10XL-MEM'],
          ['11XL-MEM (Compute Optimized)','11XL-MEM'],
          ['S-IO (Storage Optimized)','S-IO'],
          ['M-IO (Storage Optimized)','M-IO'],
          ['L-IO (Storage Optimized)','L-IO'],
          ['XL-IO (Storage Optimized)','XL-IO'],
          ['XXL-IO (Storage Optimized)','XXL-IO'],
          ['3XL-IO (Storage Optimized)','3XL-IO'],
          ['4XL-IO (Storage Optimized)','4XL-IO'],
          ['S-NET (Network Optimized)','S-NET'],
          ['M-NET (Network Optimized)','M-NET'],
          ['L-NET (Network Optimized)','L-NET'],
          ['XL-NET (Network Optimized)','XL-NET'],
          ['XXL-NET (Network Optimized)','XXL-NET'],
          ['3XL-NET (Network Optimized)','3XL-NET'],
          ['4XL-NET (Network Optimized)','4XL-NET'],
      ] }
  }

attribute 'cores',
  :description => "Number of CPU Cores",
  :grouping => 'bom',
  :format => {
    :important => true,
    :help => 'cores reported by: grep processor /proc/cpuinfo | wc -l',
    :category => '2.Resources',
    :order => 2
  }

attribute 'ram',
  :description => "Ram in MB",
  :grouping => 'bom',
  :format => {
    :important => true,
    :help => 'ram reported by: free | head -2 | tail -1 | awk \'{ print $2/1024 }\'',
    :category => '2.Resources',
    :order => 3
  }

attribute 'server_image_name',
  :description => "Server Image Name",
  :grouping => 'bom',
  :format => {
    :important => true,
    :help => 'Image name of the provisioned compute',
    :category => '3.Operating System',
    :order => 3
  }

attribute 'server_image_id',
  :description => "Server Image Id",
  :grouping => 'bom',
  :format => {
    :help => 'Image Id of the provisioned compute',
    :category => '3.Operating System',
    :order => 5
  }


# networking
attribute 'private_ip',
  :description => "Private IP",
  :grouping => 'bom',
  :format => {
    :important => true,
    :help => 'Private IP address allocated by the cloud provider',
    :category => '4.Networking',
    :order => 2
  }

attribute 'public_ip',
  :description => "Public IP",
  :grouping => 'bom',
  :format => {
    :important => true,
    :help => 'Public IP address allocated by the cloud provider',
    :category => '4.Networking',
    :order => 3
  }

attribute 'private_dns',
  :description => "Private Hostname",
  :grouping => 'bom',
  :format => {
    :help => 'Private hostname allocated by the cloud provider',
    :category => '4.Networking',
    :order => 4
  }

attribute 'public_dns',
  :description => "Public Hostname",
  :grouping => 'bom',
  :format => {
    :help => 'Public hostname allocated by the cloud provider',
    :category => '4.Networking',
    :order => 5
  }

attribute 'dns_record',
  :description => "DNS Record value used by FQDN",
  :grouping => 'bom',
  :format => {
    :help => 'DNS Record value used by FQDN',
    :category => '4.Networking',
    :order => 6
  }

attribute 'ports',
  :description => "PAT ports",
  :data_type => "hash",
  :default => '{}',
  :format => {
    :help => 'Configure the Port Address Translation PAT from internal ports (key) to external ports (value).',
    :category => '4.Networking',
    :order => 7
  }


attribute 'require_public_ip',
  :description => "Require public IP",
  :default => 'false',
  :format => {
    :help => 'Check if a public IP is required. Setting is used when the compute cloud service public networking type is interface or floating.',
    :category => '4.Networking',
    :form => { 'field' => 'checkbox' },
    :order => 10
  }

attribute 'private_ipv6',
  :description => "Private IPv6",
  :grouping => 'bom',
  :format => {
    :important => true,
    :help => 'Private IPv6 address allocated by the cloud provider',
    :category => '4.Networking',
    :order => 11
  }

attribute 'is_baremetal',
  :description => "Baremetal Compute",
  :grouping => 'bom',
  :format => {
    :important => true,
    :help => 'Compute is baremetal',
    :category => '5.Additional Properties',
    :order => 1
  }

recipe "status", "Compute Status"
recipe "reboot", "Reboot Compute"
recipe "repair", "Repair Compute"
recipe "powercycle", "Powercycle - HARD reboot"
