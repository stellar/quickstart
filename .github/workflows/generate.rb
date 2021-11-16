require 'yaml'
require 'json'

yaml = YAML::load(YAML::load(File.open('test.yml.tmpl')).to_json)
yaml.delete("-")
puts YAML.dump yaml
