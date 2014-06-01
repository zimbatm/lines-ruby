# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'lines/version'

Gem::Specification.new do |spec|
  spec.name          = "lines"
  spec.version       = Lines::VERSION
  spec.authors       = ["zimbatm"]
  spec.email         = ["zimbatm@zimbatm.com"]
  spec.summary       = %q{Lines is an opinionated structured log format}
  spec.description   = <<DESC
A log format that's readable by humans and easily parseable by computers.
DESC
  spec.homepage      = 'https://github.com/zimbatm/lines-ruby'
  spec.license       = "MIT"

  spec.files         = `git ls-files .`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "benchmark-ips"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end
