require 'date'
require 'time'

# Lines is an opinionated structured log format and a library.
#
# Log everything in development AND production.
# Logs should be easy to read, grep and parse.
# Logging something should never fail.
# Let the system handle the storage. Write to syslog or STDERR.
# No log levels necessary. Just log whatever you want.
#
# Example:
#
#     Lines.log("Oops !", foo: {}, g: [])
#     #outputs:
#     # at=2013-03-07T09:21:39+00:00 pid=3242 app=some-process msg="Oops !" foo={} g=[]
#
# Usage:
#
#     Lines.use(Syslog, $stderr)
#     Lines.log(foo: 3, msg: "This")
#
#     ctx = Lines.context(encoding_id: Log.id)
#     ctx.log({})
#
#     Lines.context(foo: 'bar') do |l|
#       l.log(items_count: 3)
#     end
module Lines
  class << self
    attr_accessor :global
    attr_reader :max_depth
    attr_reader :max_width

    # Serializer object that responds to #dump(hash)
    attr_reader :dumper

    # Master configure setup
    #
    # * output
    # * global
    # * mapping
    # * max_depth
    # * max_wdith
    def configure(config)
      global, mapping, max_depth, max_width, output =
        config.values_at(:global, :mapping, :max_depth, :max_width, :output)

      @global = global if config.key?(:global)
      @mapping = mapping if config.key?(:mapping)
      @max_depth = max_depth if config.key?(:max_depth)
      @max_width = max_width if config.key?(:max_width)
      @output = [output].flatten.compact.map{|o| to_output o} if config.key?(:output)

      @dumper = Dumper.new(
        mapping: @mapping,
        max_width: @max_width,
        max_depth: @max_depth,
      )
    end

    # Used to introduce new ruby litterals.
    #
    # Usage:
    #
    #     Point = Struct.new(:x, :y)
    #     Lines.map(Point) do |p|
    #       "#{p.x}x#{p.y}"
    #     end
    #
    #     Lines.log msg: Point.new(3, 5)
    #     # logs: msg=3x5
    #
    def map(klass, &rule)
      @mapping.merge!(klass, rule)
    end

    # DEPRECATED. Use #configure.
    #
    # outputs - allows any kind of IO or Syslog
    #
    # Usage:
    #
    #     Lines.use(Syslog, $stderr)
    #
    # Deprecated: if the last argument is a hash it replaces the globals
    def use(*outputs)
      configure(
        global: outputs.last.kind_of?(Hash) ? outputs.pop : {},
        outputs: outputs,
      )
    end

    # The main function. Used to record objects in the logs as lines.
    #
    # obj - a ruby hash. coerced to +{"msg"=>obj}+ otherwise
    # args - complementary values to put in the line
    def log(obj, args={})
      obj = prepare_obj(obj, args)
      @output.each{|out| out.output(dumper, obj) }
      nil
    end

    # Add data to the logs
    #
    # data - a ruby hash
    #
    # return a Context instance
    def context(data={})
      new_context = Context.new ensure_hash!(data)
      yield new_context if block_given?
      new_context
    end

    # Parsing object that responds to #load(string)
    def loader
      @loader ||= (
        require 'lines/loader'
        Loader
      )
    end

    # Parses a lines-formatted string
    def load(string)
      loader.load(string)
    end

    # Generates a lines-formatted string from the given object
    def dump(obj)
      dumper.dump ensure_hash!(obj)
    end

    # Returns an object compatible with the Logger interface.
    def logger
      @logger ||= (
        require 'lines/logger'
        Logger.new(self)
      )
    end

    def ensure_hash!(obj) # :nodoc:
      return {} unless obj
      return obj if obj.kind_of?(Hash)
      return obj.to_h if obj.respond_to?(:to_h)
      {msg: obj}
    end

    protected

    def prepare_obj(obj, args={})
      if obj.kind_of?(Exception)
        ex = obj
        obj = {ex: ex.class, msg: ex.to_s}
        if ex.respond_to?(:backtrace) && ex.backtrace
          obj[:backtrace] = ex.backtrace
        end
      else
        obj = ensure_hash!(obj)
      end

      args = ensure_hash!(args)

      g = global.inject({}) do |h, (k,v)|
        h[k] = (v.respond_to?(:call) ? v.call : v) rescue $!
        h
      end.merge(obj.merge(args))

      g.merge(obj.merge(args))
    end

    def to_output(out)
      return out if out.respond_to?(:output)
      return StreamOutput.new(out) if out.respond_to?(:write)
      return SyslogOutput.new if out == ::Syslog
      raise ArgumentError, "unknown outputter #{out.inspect}"
    end
  end

  # Wrapper object that holds a given context. Emitted by Lines.context
  class Context
    attr_reader :data

    def initialize(data)
      @data = data
    end

    # Works like the Lines.log method.
    def log(obj, args={})
      Lines.log obj, Lines.ensure_hash!(args).merge(data)
    end
  end

  # Handles output to any kind of IO
  class StreamOutput
    NL = "\n".freeze

    # stream must accept a #write(str) message
    def initialize(stream = $stderr)
      @stream = stream
      # Is this needed ?
      @stream.sync = true if @stream.respond_to?(:sync)
    end

    def output(dumper, obj)
      str = dumper.dump(obj) + NL
      @stream.write str
    end
  end

  require 'syslog'
  # Handles output to syslog
  class SyslogOutput
    PRI2SYSLOG = {
      'debug'    => ::Syslog::LOG_DEBUG,
      'info'     => ::Syslog::LOG_INFO,
      'warn'     => ::Syslog::LOG_WARNING,
      'warning'  => ::Syslog::LOG_WARNING,
      'err'      => ::Syslog::LOG_ERR,
      'error'    => ::Syslog::LOG_ERR,
      'crit'     => ::Syslog::LOG_CRIT,
      'critical' => ::Syslog::LOG_CRIT,
    }.freeze

    def initialize(syslog = ::Syslog)
      @syslog = syslog
    end

    def output(dumper, obj)
      prepare_syslog obj[:app]

      obj = obj.dup
      obj.delete(:pid) # It's going to be part of the message
      obj.delete(:at)  # Also part of the message
      obj.delete(:app) # And again

      level = extract_pri(obj)

      @syslog.log(level, "%s", dumper.dump(obj))
    end

    protected

    def prepare_syslog(app_name)
      return if @syslog.opened?
      app_name ||= File.basename($0)
      @syslog.open(app_name,
                  ::Syslog::LOG_PID | ::Syslog::LOG_CONS | ::Syslog::LOG_NDELAY,
                  ::Syslog::LOG_USER)
    end

    def extract_pri(h)
      pri = h.delete(:pri).to_s.downcase
      PRI2SYSLOG[pri] || ::Syslog::LOG_INFO
    end
  end

  # Some opinions here as well on the format:
  #
  # We really want to never fail at dumping because you know, they're logs.
  # It's better to get a slightly less readable log that no logs at all.
  #
  # We're trying to be helpful for humans. It means that if possible we want
  # to make things shorter and more readable. It also means that ideally
  # we would like the parsing to be isomorphic but approximations are alright.
  # For example a symbol might become a string.
  #
  # Basically, values are either composite (dictionaries and arrays), quoted
  # strings or litterals. Litterals are strings that can be parsed to
  # something else depending if the language supports it or not.
  # Litterals never contain white-spaces or other weird (very precise !) characters.
  #
  # the true litteral is written as "#t"
  # the false litteral is written as "#f"
  # the nil / null litteral is written as "nil"
  #
  # dictionary keys are always strings or litterals.
  #
  # Pleaaase, keep units with numbers. And we provide a way for this:
  # a tuple of (number, litteral) can be concatenated. Eg: (3, 'ms') => 3ms
  # alternatively if your language supports a time range it could be serialized
  # to the same value (and parsed back as well).
  #
  # if we don't know how to serialize something we provide a language-specific
  # string of it and encode is at such.
  #
  # The output ought to use the UTF-8 encoding.
  #
  # This dumper has been inspired by the OkJSON gem (both formats look alike
  # after all).
  class Dumper
    SPACE = ' '
    LIT_TRUE = '#t'
    LIT_FALSE = '#f'
    LIT_NIL = 'nil'
    OPEN_BRACE = '{'
    SHUT_BRACE = '}'
    OPEN_BRACKET = '['
    SHUT_BRACKET = ']'
    SINGLE_QUOTE = "'"
    DOUBLE_QUOTE = '"'

    constants.each(&:freeze)

    # TODO: Doc
    attr_reader :mapping

    # After a certain depth, arrays are replaced with [...] and objects with
    # {...}. Default is 4.
    attr_reader :max_depth

    # After a certain with, the end is replaced with "...". Default is nil.
    attr_reader :max_with

    def initialize(config={})
      @mapping   = config[:mapping]   || {}
      @max_depth = config[:max_depth] || 4
      @max_width = config[:max_width] || 2000
    end

    # Takes a hash and encodes it to a string
    def dump(obj, max_depth=@max_depth, max_width=@max_width) #=> String
      objenc_internal(obj, max_depth, max_width)
    end

    protected

    def objenc_internal(obj, max_depth, max_width=nil)
      max_depth -= 1
      if max_depth < 0
        '...'
      elsif max_width
        size = 0
        y = []
        obj.each_pair do |k,v|
          str = "#{keyenc(k)}=#{valenc(v, max_depth)}"
          size += str.size + 1
          if size > max_width
            y.pop if size - str.size + 3 > @max_width
            y.push '...'
            break
          end
          y.push str
        end
        y.join(SPACE)
      else
        obj.map{|k,v| "#{keyenc(k)}=#{valenc(v, max_depth)}" }.join(SPACE)
      end
    end

    def keyenc(k)
      case k
      when String, Symbol then strenc(k)
      else
        strenc(k.inspect)
      end
    end

    def valenc(x, max_depth)
      case x
      when Hash           then objenc(x, max_depth)
      when Array          then arrenc(x, max_depth)
      when String, Symbol then strenc(x)
      when Numeric        then numenc(x)
      when Time           then timeenc(x)
      when Date           then dateenc(x)
      when true           then LIT_TRUE
      when false          then LIT_FALSE
      when nil            then LIT_NIL
      else
        litenc(x)
      end
    end

    def objenc(x, max_depth)
      OPEN_BRACE + objenc_internal(x, max_depth) + SHUT_BRACE
    end

    def arrenc(a, max_depth)
      max_depth -= 1
      # num + unit. Eg: 3ms
      if a.size == 2 && a.first.kind_of?(Numeric) && is_literal?(a.last.to_s)
        "#{numenc(a.first)}:#{strenc(a.last)}"
      elsif max_depth < 0
        '[...]'
      else
        OPEN_BRACKET + a.map{|x| valenc(x, max_depth)}.join(SPACE) + SHUT_BRACKET
      end
    end

    def strenc(s)
      s = s.to_s
      unless is_literal?(s)
        s = s.inspect
        unless s[1..-2].include?(SINGLE_QUOTE)
          s.gsub!(SINGLE_QUOTE, "\\'")
          s.gsub!('\"', DOUBLE_QUOTE)
          s[0] = s[-1] = SINGLE_QUOTE
        end
      end
      s
    end

    def numenc(n)
      #case n
      # when Float
      #   "%.3f" % n
      #else
        n.to_s
      #end
    end

    def litenc(x)
      klass = (x.class.ancestors & mapping.keys).first
      if klass
        mapping[klass].call(x)
      else
        strenc(x.inspect)
      end
    rescue
      klass = (class << x; self; end).ancestors.first
      strenc("#<#{klass}:0x#{x.__id__.to_s(16)}>")
    end

    def timeenc(t)
      t.utc.iso8601
    end

    def dateenc(d)
      d.iso8601
    end

    def is_literal?(s)
      !s.index(/[\s'"=:{}\[\]]/)
    end
  end

  require 'securerandom'
  module UniqueIDs
    # A small utility to generate unique IDs that are as short as possible.
    #
    # It's useful to link contextes together
    #
    # See http://preshing.com/20110504/hash-collision-probabilities
    def id(collision_chance=1.0/10e9, over_x_messages=10e3)
      # Assuming that the distribution is perfectly random
      # how many bits do we need so that the chance of collision over_x_messages
      # is lower thant collision_chance ? 
      number_of_possible_numbers = (over_x_messages ** 2) / (2 * collision_chance)
      num_bytes = (Math.log2(number_of_possible_numbers) / 8).ceil
      SecureRandom.urlsafe_base64(num_bytes)
    end
  end
  extend UniqueIDs
end

# default config
Lines.configure(
  output: $stderr,
  global: {},
  mapping: {},
  max_depth: 4,
  # rsyslog's default is 2048, this gives a bit of room for the pid and hostname
  max_width: 2000,
)
