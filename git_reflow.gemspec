# frozen_string_literal: true

# Ensure we require the local version and not one we might have installed already
require File.join([File.dirname(__FILE__), 'lib', 'git_reflow/version.rb'])
Gem::Specification.new do |s|
  s.name          = 'git_reflow'
  s.version       = GitReflow::VERSION
  s.license       = 'MIT'
  s.authors       = ['Valentino Stoll', 'Robert Stern', 'Nicholas Hance']
  s.email         = ['dev@reenhanced.com']
  s.homepage      = 'http://github.com/reenhanced/gitreflow'
  s.summary       = 'A better git process'
  s.description   = 'Git Reflow manages your git workflow.'
  s.platform      = Gem::Platform::RUBY
  s.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = s.files.grep(%r{^exe/}) { |f| File.basename(f) }
  s.bindir        = 'exe'
  s.require_paths = ['lib']
  s.rdoc_options << '--title' << 'git_reflow' << '-ri'

  s.add_development_dependency('appraisal', '2.2.0')
  s.add_development_dependency('chronic')
  s.add_development_dependency('pry-byebug')
  s.add_development_dependency('rake', '~> 13.0.1')
  s.add_development_dependency('rdoc')
  s.add_development_dependency('rspec', '~> 3.9')
  s.add_development_dependency('webmock')
  s.add_development_dependency('wwtd', '1.4')

  s.add_dependency('bundler', '>= 1.10.0')
  s.add_dependency('codenamev_bitbucket_api', '0.4.1')
  s.add_dependency('colorize', '>= 0.7.0')
  s.add_dependency('github_api', '0.18.2')
  s.add_dependency('highline')
  s.add_dependency('httpclient')

  s.post_install_message = "You need to setup your GitHub OAuth token\nPlease run 'git-reflow setup'"
end
