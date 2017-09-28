name             "Keypair"
description      "General purpose key pairs"
version          "0.1"
maintainer       "OneOps, Inc."
maintainer_email "support@oneops.com"
license          "Apache License, Version 2.0"
depends          "azurekeypair"

grouping 'default',
  :access => "global",
  :packages => [ 'base', 'account', 'mgmt.catalog', 'mgmt.manifest', 'catalog', 'manifest' ]

grouping 'bom',
  :access => "global",
  :packages => [ 'bom' ]

attribute 'description',
  :description => "Description",
  :default => "",
  :format => {
    :help => 'Enter description',
    :category => '1.Global',
    :order => 1
  }

attribute 'private',
  :description => "Private RSA Key",
  :grouping => 'bom',
  :data_type => "text",
  :encrypted => true,
  :required => "required",
  :default => "",
  :format => {
    :help => 'Private RSA key',
    :category => '1.Global',
    :order => 2 ,
    :editable => false
  }

attribute 'public',
  :description => "Public RSA Key",
  :grouping => 'bom',
  :data_type => "text",
  :required => "required",
  :default => "",
  :format => {
    :help => 'Public RSA key',
    :category => '1.Global',
    :order => 3 ,
    :editable => false
  }

# bom
attribute 'fingerprint',
  :description => "Fingerprint",
  :grouping => 'bom',
  :format => {
    :help => 'Public key fingerprint',
    :category => '1.Global',
    :important => true,
    :order => 4
  }

attribute 'certificate',
  :description => "Certificate",
  :grouping => 'bom',
  :data_type => "text",
  :format => {
    :help => 'PEM certificate from the public key',
    :category => '1.Global',
    :order => 5
  }

attribute 'key_name',
  :description => "Key Name",
  :grouping => 'bom',
  :data_type => "text",
  :format => {
    :help => 'Key-Name value pair',
    :category => '1.Global',
    :order => 6
  }


recipe "repair", "Repair"
