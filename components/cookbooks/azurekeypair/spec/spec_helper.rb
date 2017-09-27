require 'chefspec'
require 'crack'
require 'rest-client'
require 'simplecov'
SimpleCov.start

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end

if defined?(ChefSpec)
  ChefSpec.define_matcher :azurekeypair_resource_group
  ChefSpec.define_matcher :azurekeypair_availability_set

  # @param [String] resource_name
  #   the resource name
  #
  # @return [ChefSpec::Matchers::ResourceMatcher]

  def add_azurekeypair_resource_group(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:azurekeypair_resource_group, :create, resource_name)
  end

  def delete_azurekeypair_resource_group(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:azurekeypair_resource_group, :destroy, resource_name)
  end

  def add_azurekeypair_availability_set(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:azurekeypair_availability_set, :create, resource_name)
  end
end
