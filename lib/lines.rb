# -*- encoding : utf-8 -*-

require 'lines/parser'
require 'lines/generator'
require 'lines/version'

# Lines is an opinionated structured log format
module Lines; extend self
  # The global default options for the Lines.parse and Lines.load method:
  #   max_nesting: 100
  #   symbolize_names: false
  attr_reader :parse_default_options
  @parse_default_options = {
    max_nesting: 100,
    symbolize_names: false,
  }

  # The global default options for the Lines.dump method:
  #   max_nesting: 4
  #   pretty_strings: true
  attr_reader :generate_default_options
  @generate_default_options = {
    max_nesting: 4,
    pretty_strings: true,
  }

  attr_accessor :parser
  @parser = Parser

  attr_accessor :generator
  @generator = Generator

  # Parse the Lines string _source_ into a Ruby data structure and return it.
  #
  # _options_ can have the following keys:
  # * *max_nesting*: The maximum depth of nesting allowed in the parsed data
  #   structures. It defaults to 100.
  # * *symbolize_names*: If set to true, returns symbols for the names
  #   (keys) in a Lines object. Otherwise strings are returned. Strings are
  #   the default.
  def parse(source, options = {})
    opts = Lines.parse_default_options.merge(options.to_hash)
    @parser.parse(source.to_str, opts)
  end

  # Generate a Lines string from the Ruby data structure _obj_ and return
  # it.
  #
  # _options_ can have the following keys:
  # * *max_nesting*: The maximum depth of nesting allowed in the data
  #   structures from which Lines is to be generated. It defaults to 4.
  def generate(obj, options = {})
    opts = Lines.generate_default_options.merge(options.to_hash)
    @generator.generate(obj.to_hash, opts)
  end

  
  # Load a ruby data structure from a Lines _source_ and return it. A source can
  # either be a string-like object, an IO-like object, or an object responding
  # to the read method. If _proc_ was given, it will be called with any nested
  # Ruby object as an argument recursively in depth first order. To modify the
  # default options pass in the optional _options_ argument as well.
  #
  # This method is part of the implementation of the load/dump interface of
  # Marshal and YAML.
  def load(source, proc = nil, options = {})
    if source.respond_to? :to_str
      source = source.to_str
    elsif source.respond_to? :to_io
      source = source.to_io.read
    elsif source.respond_to?(:read)
      source = source.read
    end
    result = parse(source, options)
    recurse_proc(result, &proc) if proc
    result
  end

  # Recursively calls passed _Proc_ if the parsed data structure is an _Array_ or _Hash_
  def recurse_proc(result, &proc)
    case result
    when Array
      result.each { |x| recurse_proc x, &proc }
      proc.call result
    when Hash
      result.each { |x, y| recurse_proc x, &proc; recurse_proc y, &proc }
      proc.call result
    else
      proc.call result
    end
  end
  protected :recurse_proc

  # Dumps _obj_ as a Lines string, i.e. calls generate on the object and returns
  # the result.
  #
  # If anIO (an IO-like object or an object that responds to the write method)
  # was given, the resulting JSON is written to it.
  #
  # If the number of nested arrays or objects exceeds _limit_, an ArgumentError
  # exception is raised. This argument is similar (but not exactly the
  # same!) to the _limit_ argument in Marshal.dump.
  # FIXME: right now it replaces deep elements with [...] and {...}
  #
  # The default options for the generator can be changed via the
  # dump_default_options method.
  #
  # This method is part of the implementation of the load/dump interface of
  # Marshal and YAML.
  def dump(obj, anIO = nil, limit = nil)
    if anIO and limit.nil?
      anIO = anIO.to_io if anIO.respond_to?(:to_io)
      unless anIO.respond_to?(:write)
        limit = anIO
        anIO = nil
      end
    end
    opts = {}
    opts[:max_nesting] = limit if limit
    result = generate(obj, opts)
    if anIO
      anIO.write result
      anIO
    else
      result
    end
  end
end
