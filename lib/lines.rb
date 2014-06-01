require 'lines/parser'
require 'lines/generator'
require 'lines/version'

# Lines is an opinionated structured log format
module Lines; extend self
  attr_accessor :parser, :generator

  @parser = Parser
  @generator = Generator

  # Parses a lines-formatted string
  def load(string, opts={})
    parser.load(string.to_s, opts)
  end

  # Generates a lines-formatted string from the given object
  def dump(obj, opts={})
    generator.dump(obj.to_h, opts)
  end
end
