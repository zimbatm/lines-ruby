# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'lines/version'

Gem::Specification.new do |spec|
  spec.name          = "lines"
  spec.version       = Lines::VERSION
  spec.authors       = ["Jonas Pfenniger"]
  spec.email         = ["jonas@pfenniger.name"]
  spec.description   = %q{structured logs for humans}
  spec.summary       = %q{Lines is an opinionated structured logging library}
  spec.homepage      = 'https://github.com/zimbatm/lines-ruby'
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rspec"
end
