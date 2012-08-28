# Ensure we require the local version and not one we might have installed already
require File.join([File.dirname(__FILE__),'lib','git_reflow/version.rb'])
spec = Gem::Specification.new do |s|
  s.name             = 'git_reflow'
  s.version          = GitReflow::VERSION
  s.authors          = ["Valentino Stoll", "Robert Stern", "Nicholas Hance"]
  s.email            = ["dev@reenhanced.com"]
  s.homepage         = "http://github.com/reenhanced/gitreflow"
  s.summary          = "A better git process"
  s.description      = "Git Reflow manages your git workflow."
  s.platform         = Gem::Platform::RUBY
  s.files            = `git ls-files`.split("\n")
  s.test_files       = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables      = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.has_rdoc         = true
  s.extra_rdoc_files = ['README.rdoc']
  s.bindir           = 'bin'
  s.require_paths    << 'lib'
  s.rdoc_options     << '--title' << 'git_reflow' << '--main' << 'README.rdoc' << '-ri'
  s.add_development_dependency('rake')
  s.add_development_dependency('rdoc')
  s.add_development_dependency('rspec')
  s.add_development_dependency('aruba', '~> 0.4.6')
  s.add_development_dependency('jeweler')
  s.add_development_dependency('webmock')
  s.add_dependency('gli', '2.0.0')
  s.add_dependency('json_pure', '1.7.5')
  s.add_dependency('highline')
  s.add_dependency('httpclient')
  s.add_dependency('github_api', '0.6.5')
  s.post_install_message = "You need to setup your GitHub OAuth token\nPlease run 'git-reflow setup'"
end
