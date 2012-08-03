require 'rake'
require 'cucumber'
require 'cucumber/rake/task'

Dir[File.join(File.dirname(__FILE__),'lib/tasks/*.rake')].each { |f| load f }

Cucumber::Rake::Task.new(:features) do |t|
  t.cucumber_opts = "features --format pretty -x"
  t.fork = false
end

task :default => [:spec, :cucumber]
