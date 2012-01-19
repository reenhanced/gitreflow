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
end
