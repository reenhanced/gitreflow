require 'erb'
require 'ostruct'

class Fixture
  attr_accessor :file, :locals

  def initialize(file, locals = {})
    @file   = fixture(file)
    @locals = locals
  end

  def fixture_path
    File.expand_path("../../fixtures", __FILE__)
  end

  def fixture(file)
    File.new(File.join(fixture_path, "/", file)).read
  end

  def to_s
    file.to_s
  end

  def to_json
    if File.extname(file) == ".erb"
      rendered_file = ERB.new(fixture).result(OpenStruct.new(locals).instance_eval { binding })
      JSON.parse(rendered_file)
    else
      JSON.parse(file)
    end
  end

  def to_json_hashie
    json = self.to_json
    if json.is_a? Array
      json.map {|json_object| Hashie::Mash.new json_object }
    else
      Hashie::Mash.new json
    end
  end
end
