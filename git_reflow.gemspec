lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'git_reflow/version'

Gem::Specification.new do |spec|
  spec.name = "git_reflow"
  spec.version = GitReflow::VERSION
  spec.platform = Gem::Platform::RUBY
  spec.authors = ["Valentino Stoll", "Robert Stern", "Nicholas Hance"]
  spec.email = ["dev@reenhanced.com"]
  spec.homepage = "http://github.com/reenhanced/gitreflow"
  spec.summary = "A better git process"
  spec.description = "Git Reflow manages your git workflow."
  spec.require_path = "lib"
  spec.add_development_dependency('aruba', '~> 0.4.6')
  spec.add_development_dependency('rake')
  spec.add_development_dependency('rspec')
  spec.add_development_dependency('jeweler')
  spec.add_dependency('gli')
  spec.add_dependency('json')
  spec.add_dependency('httpclient')
end
