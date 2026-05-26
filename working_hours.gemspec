# frozen_string_literal: true

require 'English'

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'working_hours/version'

Gem::Specification.new do |spec|
  spec.name          = 'working_hours'
  spec.version       = WorkingHours::VERSION
  spec.authors       = ['Adrien Jarthon', 'Intrepidd']
  spec.email         = ['me@adrienjarthon.com', 'adrien@siami.fr']
  spec.summary       = 'time calculation with working hours'
  spec.description   = 'A modern ruby gem allowing to do time calculation with working hours.'
  spec.homepage      = 'https://github.com/intrepidd/working_hours'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport', '>= 7.0'
  spec.add_dependency 'tzinfo'

  spec.add_development_dependency 'bundler', '>= 1.5'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.2'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-rspec'
  spec.add_development_dependency 'timecop'
end
