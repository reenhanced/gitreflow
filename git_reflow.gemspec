lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'git_reflow/version'

Gem::Specification.new do |s|
  s.name = "git_reflow"
  s.version = GitReflow::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Valentino Stoll", "Robert Stern", "Nicholas Hance"]
  s.email = ["dev@reenhanced.com"]
  s.homepage = "http://github.com/reenhanced/gitreflow"
  s.summary = "A better git process"
  s.description = "Git Reflow manages your git workflow."

  s.add_development_dependency('aruba', '~> 0.4.6')
  s.add_development_dependency('rake')
  s.add_development_dependency('rspec')
  s.add_development_dependency('jeweler')
  s.add_dependency('gli')
  s.add_dependency('json')
  s.add_dependency('httpclient')

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
