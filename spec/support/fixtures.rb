# ERB parsing credit:
# http://stackoverflow.com/questions/8954706/render-an-erb-template-with-values-from-a-hash/9734736#9734736

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
    File.new(File.join(fixture_path, "/", file))
  end

  def to_s
    if File.extname(file) == ".erb"
      ERB.new(template_file_content).result(OpenStruct.new(locals).instance_eval { binding }).to_s
    else
      template_file_content.to_s
    end
  end

  def to_json
    if File.extname(file) == ".erb"
      rendered_file = ERB.new(template_file_content).result(OpenStruct.new(locals).instance_eval { binding })
      JSON.parse(rendered_file)
    else
      JSON.parse(template_file_content)
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

  private

  def template_file_content
    @file_content ||= file.read
  end
end
