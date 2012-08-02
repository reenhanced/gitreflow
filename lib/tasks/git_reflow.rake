require File.join([File.dirname(__FILE__),'..','git_reflow/version.rb'])
namespace :gitreflow do
  desc "Builds and re-installs the latest gem from source"
  task :reinstall do
    exec("gem uninstall git_reflow")
    exec("gem build git_reflow.gemspec")
    exec("gem install git_reflow-#{GitReflow::VERSION}.gem")
  end
end
