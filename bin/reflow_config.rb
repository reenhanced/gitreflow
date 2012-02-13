require 'yaml'

options = {
  :'default-branch' => 'master'
}

CONFIG_FILE = File.join(ENV['HOME'], '.reflow_config.yaml')
if File.exists? CONFIG_FILE
  options_config = YAML.load_file(CONFIG_FILE)
  options.merge!(options_config)
else
  File.open(CONFIG_FILE, 'w') { |file| YAML::dump(options, file) }
  STDERR.puts "Initialized configuration file in #{CONFIG_FILE}"
end
