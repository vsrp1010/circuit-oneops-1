name             "Secgroup"
description      "Security group"
version          "0.1"
maintainer       "OneOps, Inc."
maintainer_email "support@oneops.com"
license          "Apache License, Version 2.0"
depends          "azuresecgroup"

grouping 'default',
  :access => "global",
  :packages => [ 'base', 'account', 'mgmt.catalog', 'mgmt.manifest', 'catalog', 'manifest' ]

grouping 'bom',
  :access => "global",
  :packages => [ 'bom' ]


attribute 'group_id',
  :grouping => 'bom',
  :description => "Group ID",
  :default => "",
  :format => {
    :important => true,
    :help => 'Group Identifier',
    :category => '1.Global',
    :order => 1
  }

attribute 'group_name',
  :grouping => 'bom',
  :description => "Group Name",
  :default => "",
  :format => {
    :important => true,
    :help => 'Group Name',
    :category => '1.Global',
    :order => 2
  }

attribute 'description',
  :description => "Description",
  :default => "",
  :format => {
    :help => 'Enter description',
    :category => '1.Global',
    :order => 3
  }

attribute 'inbound',
  :description => "Inbound Rules",
  :data_type => "array",
  :default => '[ "22 22 tcp 0.0.0.0/0" ]',
  :format => {
    :important => true,
    :help => 'Specify inbound rules in the form:  min max protocol cidr.  Do not delete the port 22 rule, it is used to manage.',
    :category => '2.Rules',
    :order => 1
  }

recipe "repair", "Repair Secgroup"
