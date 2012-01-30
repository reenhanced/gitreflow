# Ensure we require the local version and not one we might have installed already
require File.join([File.dirname(__FILE__),'lib','git_reflow/version.rb'])
spec = Gem::Specification.new do |s| 
  s.name = 'git_reflow'
  s.version = GitReflow::VERSION
  s.authors = ["Valentino Stoll", "Robert Stern", "Nicholas Hance"]
  s.email = ["dev@reenhanced.com"]
  s.homepage = "http://github.com/reenhanced/gitreflow"
  s.summary = "A better git process"
  s.description = "Git Reflow manages your git workflow."
  s.platform = Gem::Platform::RUBY
# Add your other files here if you make them
  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths << 'lib'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.rdoc']
  s.rdoc_options << '--title' << 'git_reflow' << '--main' << 'README.rdoc' << '-ri'
  s.bindir = 'bin'
  s.add_development_dependency('rake')
  s.add_development_dependency('rdoc')
  s.add_development_dependency('aruba', '~> 0.4.6')
  s.add_development_dependency('rspec')
  s.add_development_dependency('jeweler')
  s.add_dependency('gli')
  s.add_dependency('json')
  s.add_dependency('httpclient')
end
