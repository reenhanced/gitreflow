require "thor"
require "stringio"

require_relative 'rspec/command_line_helpers'
require_relative 'rspec/stub_helpers'

#####################################################################
# Stub Thor
# credit: https://github.com/erikhuda/thor/blob/master/spec/helper.rb
#####################################################################

# Set shell to color
$0 = "thor"
$thor_runner = true
ARGV.clear
Thor::Base.shell = Thor::Shell::Color

#RSpec.configure do |config|
#  config.before do
#    ARGV.replace []
#  end
#
#  config.expect_with :rspec do |c|
#    c.syntax = :expect
#  end
#
#  def capture(stream)
#    begin
#      stream = stream.to_s
#      eval "$#{stream} = StringIO.new"
#      yield
#      result = eval("$#{stream}").string
#    ensure
#      eval("$#{stream} = #{stream.upcase}")
#    end
#
#    result
#  end
#
#  def source_root
#    File.join(File.dirname(__FILE__), "..", "..", "spec", "fixtures")
#  end
#
#  def destination_root
#    File.join(File.dirname(__FILE__), "..", "..", "spec", "sandbox")
#  end
#
#  # This code was adapted from Ruby on Rails, available under MIT-LICENSE
#  # Copyright (c) 2004-2013 David Heinemeier Hansson
#  def silence_warnings
#    old_verbose = $VERBOSE
#    $VERBOSE = nil
#    yield
#  ensure
#    $VERBOSE = old_verbose
#  end
#
#  alias silence capture
#end
