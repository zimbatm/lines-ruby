$:.unshift File.expand_path('../lib', __FILE__)
require 'lines/version'

Gem::Specification.new do |s|
  s.name = 'lines'
  s.version = Lines::VERSION
  s.homepage = 'https://github.com/zimbatm/lines-ruby'
  s.summary = 'structured logs for humans'
  s.description = 'structured logs for humans'
  s.author = 'Jonas Pfenniger'
  s.email = 'jonas@pfenniger.name'
  s.files = ['README.md'] + Dir['lib/**/*.rb'] + Dir['test/**/*.rb']
  s.require_paths = %w[lib]
end
