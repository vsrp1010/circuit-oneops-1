name             "Storage"
description      "Storage"
version          "0.1"
maintainer       "OneOps"
maintainer_email "support@oneops.com"
license          "Apache License, Version 2.0"
depends "shared"
depends "azuredatadisk"

grouping 'default',
  :access => "global",
  :packages => [ 'base', 'mgmt.catalog', 'mgmt.manifest', 'catalog', 'manifest' ]

grouping 'bom',
 :access => "global",
 :packages => [ 'bom' ]

attribute 'size',
  :description => "Size",
  :required => "required",
  :default => "100G",
  :format => { 
    :help => 'Total storage size to be allocated specified in GB (Note: specific raid configurations will result in smaller usable volume size)',
    :category => '1.Configuration',
    :order => 1
  }

attribute 'slice_count',
  :description => "Slice Count",
  :required => "required",
  :default => "1",
  :format => { 
    :help => 'Number of slices / block storage volumes (Note: needs to be even number if you intend to use it for raid10 or raid1 volumes)',
    :category => '1.Configuration',
    :order => 2,
    :patter => "[0-9]+",
    :editable => true
  }

attribute 'volume_type',
  :description => "Storage Type",
  :required => "optional",
  :default => "STANDARD1",
  :format => {
    :help => 'Select the storage type.Storage_types are mapped against volume types offered by cloud providers - see provider documentation for details. Storage type determines the volume type(IOPS) and service level(bandwidth).',
    :category => '1.Configuration',
    :order => 3,
    :form => { 'field' => 'select', 'options_for_select' => [
      ["Standard-1", "STANDARD1"],
      ["IOPS-1", "IOPS1"],
      ] }
  }   
# maps provider vol-id for md
attribute 'device_map',
  :description => "Device Map",
  :grouping => "bom",
  :default => "",
  :format => { 
    :help => 'Resulting device map after allocation of the storage resources',
    :category => '2.Devices',
    :order => 1
  } 


recipe "repair", "Repair Storage"
