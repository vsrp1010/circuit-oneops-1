require File.expand_path('../../libraries/utils.rb', __FILE__)
require 'json'

describe 'tags for resource' do

  it 'contains Organization tags from workorder' do
    wo = File.expand_path('workorders/workorder.json', File.dirname(__FILE__))
    node = JSON.parse(File.read(wo))

    tags = Utils.get_resource_tags(node)
    expect(tags).to include("tag1")
    expect(tags).to include("tag2")

  end

  it 'contains Assembly tags from workorder' do
    wo = File.expand_path('workorders/workorder.json', File.dirname(__FILE__))
    node = JSON.parse(File.read(wo))

    tags = Utils.get_resource_tags(node)
    expect(tags).to include("tag3")
    expect(tags).to include("tag1")

  end

  it 'overrides Organization tags with Assembly tags when same name is used' do
    wo = File.expand_path('workorders/workorder.json', File.dirname(__FILE__))
    node = JSON.parse(File.read(wo))

    tags = Utils.get_resource_tags(node)
    expect(tags).to include("tag1" => "from assembly")
    expect(tags).to include("tag2")
    expect(tags).to include("tag3")

  end

  it 'has tag named owner' do
    wo = File.expand_path('workorders/workorder.json', File.dirname(__FILE__))
    node = JSON.parse(File.read(wo))

    tags = Utils.get_resource_tags(node)
    expect(tags).to include('owner')
  end
end