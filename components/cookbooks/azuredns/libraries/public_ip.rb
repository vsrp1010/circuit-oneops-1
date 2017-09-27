require 'chef'
require ::File.expand_path('../../../azure/libraries/public_ip.rb', __FILE__)
::Chef::Recipe.send(:include, AzureNetwork)

# AzureDns Module
module AzureDns
  # PublicIp Class
  class PublicIp
    attr_accessor :pubip

    def initialize(resource_group, creds, zone_name)
      @resource_group = resource_group
      @pubip = AzureNetwork::PublicIp.new(creds)
      @zone_name = zone_name
    end

    def update_dns(node)
      domain_name_label = nil
      domain_name_label = update_dns_for_os node if node['app_name'] == 'os'
      domain_name_label = update_dns_for_fqdn node if node['app_name'] == 'fqdn'
      domain_name_label = update_dns_for_lb node if node['app_name'] == 'lb'
      domain_name_label
    end

    def update_dns_for_os(node)
      public_ip_name = Utils.get_component_name('publicip', node['workorder']['payLoad']['DependsOn'][0]['ciId'])
      pip = @pubip.get(@resource_group, public_ip_name)
      unless node['full_hostname'].nil?
        full_hostname = node['full_hostname'].split('.').reverse.join('.').partition('.').last.split('.').reverse.join('.').downcase
        Chef::Log.info('domain name label :' + full_hostname)
        full_hostname = full_hostname.tr('.', '-')
        pip.domain_name_label = (full_hostname.length >= 61) ? full_hostname.slice!(0, 60) : full_hostname
        @pubip.create_update(@resource_group, public_ip_name, pip).domain_name_label
      end
    end

    def update_dns_for_fqdn(node)
      new_dns_settings = Fog::Network::AzureRM::PublicIp.new
      short_name_available = false
      public_ip_name = nil
      # create a new dns settings object with the new values.
      # only setting the domain_name_label
      # the fqdn automatically gets populated with the name label and "<location>.cloudapp.azure.com"
      if node['workorder']['rfcCi']['ciAttributes'].key?('aliases')
        begin
          shortnames = node['workorder']['rfcCi']['ciAttributes']['aliases'] == "" ? "" : JSON.parse(node['workorder']['rfcCi']['ciAttributes']['aliases'])
        end
      end
      unless shortnames.empty?
        if !shortnames[0].empty?
          short_name_available = true
          Chef::Log.info('shortnames:' + shortnames[0])
          # whether to add zone or not ?? currently no zone is added.
          new_dns_settings.domain_name_label = (shortnames[0]).downcase # + "-"+@zone_name
        else
          Chef::Log.info('short name is empty. User didnt supply shortname ')
        end
      end
      availability = node['workorder']['box']['ciAttributes']['availability']
      if availability == 'single'
        dependson = node[:workorder][:payLoad][:DependsOn]
        dependson.each do |depends|
          public_ip_name = Utils.get_component_name('publicip', depends['ciId']) if depends['ciAttributes'].key?('instance_name')
          next if short_name_available
          next unless depends['ciAttributes'].key?('hostname')
          full_hostname = depends['ciAttributes']['hostname']
          Chef::Log.info('full_hostname:' + full_hostname)
          full_hostname = full_hostname.split('.').reverse.join('.').partition('.').last.split('.').reverse.join('.').downcase
          Chef::Log.info('domain name label :' + full_hostname)
          full_hostname = full_hostname.tr('.', '-')
          new_dns_settings = Fog::Network::AzureRM::PublicIp.new
          if full_hostname.length >= 61
            new_dns_settings.domain_name_label = full_hostname.slice!(0, 60)
            new_dns_settings.domain_name_label.chomp!('-') if new_dns_settings.domain_name_label[59] == '-'
          else
            new_dns_settings.domain_name_label = full_hostname
          end
        end
        unless new_dns_settings.domain_name_label.nil?
          Chef::Log.info('setting domain label: ' + new_dns_settings.domain_name_label)
          unless public_ip_name.nil?
            pip = @pubip.get(@resource_group, public_ip_name)
            pip.domain_name_label = new_dns_settings.domain_name_label
            ## update the public ip with the new dns settings
            return @pubip.create_update(@resource_group, public_ip_name, pip).domain_name_label
          end
        end
      elsif availability == 'redundant'
        Chef::Log.info('environment:' + availability)
        if node['workorder']['payLoad'].key?('lb')
          lb_list = node['workorder']['payLoad']['lb']
          lb_list.each do |lb|
            ci_id = lb['ciId'] if lb.key?('ciId')
            public_ip_name = Utils.get_component_name('lb_publicip', ci_id)
            Chef::Log.info('lb_publicip name :' + public_ip_name)
            if short_name_available == false
              Chef::Log.info('shortname is unavailable')
              instance = node['workorder']['payLoad']['DependsOn'][0]['ciId'].to_s
              cloud_id = node['workorder']['rfcCi']['ciName'].split('-', 2).last
              subdomain = node['workorder']['payLoad']['Environment'][0]['ciAttributes']['subdomain']
              new_dns_settings.domain_name_label = Utils.get_dns_domain_label('lb', cloud_id, instance, subdomain) + '-' + @zone_name

              if new_dns_settings.domain_name_label.length >= 61
                new_dns_settings.domain_name_label = new_dns_settings.domain_name_label.slice!(0, 60)
                new_dns_settings.domain_name_label.chomp!('-') if new_dns_settings.domain_name_label[59] == '-'
              end
            end
            next if new_dns_settings.domain_name_label.nil?
            Chef::Log.info('domain label: ' + new_dns_settings.domain_name_label)
            next if public_ip_name.nil?
            Chef::Log.info('searching public_ip_name:' + public_ip_name + 'in' + @resource_group)
            ip_found = @pubip.check_existence_publicip(@resource_group, public_ip_name)
            next unless ip_found
            Chef::Log.info('found !')
            pip = @pubip.get(@resource_group, public_ip_name)
            OOLog.info("PIP IS: #{pip.inspect}")
            OOLog.info("PIP DNS Settings are: '#{pip.domain_name_label}'")
            pip.domain_name_label = new_dns_settings.domain_name_label
            Chef::Log.info('updating domain label: ' + new_dns_settings.domain_name_label)
            # update the public ip with the new dns settings
            return @pubip.create_update(@resource_group, public_ip_name, pip).domain_name_label
          end
        end
      end
    end

    def update_dns_for_lb(node)
      instance = node['workorder']['rfcCi']['ciId'].to_s
      cloud_id = node['workorder']['rfcCi']['ciName'].split('-', 2).last
      subdomain = node['workorder']['payLoad']['Environment'][0]['ciAttributes']['subdomain']
      domain_name_label = Utils.get_dns_domain_label('lb', cloud_id, instance, subdomain) + '-' + @zone_name
      domain_name_label = domain_name_label.slice(0, 60) if domain_name_label.length >= 61
      Chef::Log.info('domain label is: ' + domain_name_label)
      domain_name_label
    end
  end
end
