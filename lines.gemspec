$:.unshift File.expand_path('../lib', __FILE__)
require 'lines/version'

Gem::Specification.new do |s|
  s.name = 'lines'
  s.version = Lines::VERSION
  s.homepage = 'https://github.com/zimbatm/lines'
  s.summary = 'Logging revisited'
  s.description = 'Lines is a cross-language logging format'
  s.author = 'Jonas Pfenniger'
  s.email = 'jonas@pfenniger.name'
  s.files = ['README.md'] + Dir['lib/**/*.rb'] + Dir['test/**/*.rb']
  s.require_paths = %w[lib]
end
