# Generate basic YAML from YAML that includes aliases.

require 'yaml'
require 'json'

# Run YAML->JSON->YAML to expand all aliaeses and to form basic YAML.
yaml = YAML::load(YAML::load(ARGF).to_json)

# Delete the alias'd component.
yaml.delete("-")

# Send the result to STDOUT.
puts '# This workflow is generated from a workflow template.'
puts '# DO NOT EDIT or your changes may be overwritten.'
puts YAML.dump yaml
