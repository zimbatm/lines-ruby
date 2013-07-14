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
#     log("Oops !", foo: {}, g: [])
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
  # New lines in Lines
  NL = "\n".freeze

  class << self
    attr_reader :global
    attr_writer :loader, :dumper

    # Parsing object. Responds to #load(string)
    def loader
      @loader ||= (
        require 'lines/loader'
        Loader
      )
    end

    # Serializing object. Responds to #dump(hash)
    def dumper; @dumper ||= Dumper.new end

    # Returns a backward-compatibile Logger
    def logger
      @logger ||= (
        require 'lines/logger'
        Logger.new(self)
      )
    end

    # Used to configure lines.
    #
    # outputs - allows any kind of IO or Syslog
    #
    # Usage:
    #
    #     Lines.use(Syslog, $stderr, at: proc{ Time.now })
    def use(*outputs)
      if outputs.last.kind_of?(Hash)
        @global = outputs.pop
      else
        @global = {}
      end
      @outputters = outputs.flatten.map{|o| to_outputter o}
    end

    # The main function. Used to record objects in the logs as lines.
    #
    # obj - a ruby hash. coerced to +{"msg"=>obj}+ otherwise
    # args - complementary values to put in the line
    def log(obj, args={})
      obj = prepare_obj(obj, args)
      @outputters.each{|out| out.output(dumper, obj) }
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

    def ensure_hash!(obj) # :nodoc:
      return {} unless obj
      return obj if obj.kind_of?(Hash)
      return obj.to_h if obj.respond_to?(:to_h)
      obj = {msg: obj}
    end

    # Parses a lines-formatted string
    def load(string)
      loader.load(string)
    end

    # Generates a lines-formatted string from the given object
    def dump(obj)
      dumper.dump ensure_hash!(obj)
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
      end

      g.merge(obj.merge(args))
    end

    def to_outputter(out)
      return out if out.respond_to?(:output)
      return StreamOutputter.new(out) if out.respond_to?(:write)
      return SyslogOutputter.new if out == ::Syslog
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
  class StreamOutputter
    # stream must accept a #write(str) message
    def initialize(stream = $stderr)
      @stream = stream
      # Is this needed ?
      @stream.sync = true if @stream.respond_to?(:sync)
    end

    def output(dumper, obj)
      str = dumper.dump(obj) + NL
      stream.write str
    end

    protected

    attr_reader :stream
  end

  require 'syslog'
  # Handles output to syslog
  class SyslogOutputter
    PRI2SYSLOG = {
      'debug'    => Syslog::LOG_DEBUG,
      'info'     => Syslog::LOG_INFO,
      'warn'     => Syslog::LOG_WARNING,
      'warning'  => Syslog::LOG_WARNING,
      'err'      => Syslog::LOG_ERR,
      'error'    => Syslog::LOG_ERR,
      'crit'     => Syslog::LOG_CRIT,
      'critical' => Syslog::LOG_CRIT,
    }

    def initialize(syslog = Syslog)
      @syslog = syslog
    end

    def output(dumper, obj)
      prepare_syslog obj[:app]

      obj = obj.dup
      obj.delete(:pid) # It's going to be part of the message
      obj.delete(:at)  # Also part of the message
      obj.delete(:app) # And again

      level = extract_pri(obj)
      str = dumper.dump(obj)

      @syslog.log(level, "%s", str)
    end

    protected

    def prepare_syslog(app_name)
      return if @syslog.opened?
      app_name ||= File.basename($0)
      @syslog.open(app_name,
                  Syslog::LOG_PID | Syslog::LOG_CONS | Syslog::LOG_NDELAY,
                  Syslog::LOG_USER)
    end

    def extract_pri(h)
      pri = h.delete(:pri).to_s.downcase
      PRI2SYSLOG[pri] || Syslog::LOG_INFO
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
    def dump(obj) #=> String
      objenc_internal(obj)
    end

    # Used to introduce new ruby litterals.
    def map(klass, &rule)
      @mapping[klass] = rule
    end

    # After a certain depth, arrays are replaced with [...] and objects with
    # {...}. Default is 4.
    attr_accessor :max_depth

    protected

    attr_reader :mapping

    def initialize
      @mapping = {}
      @max_depth = 4
    end

    def objenc_internal(x, depth=0)
      depth += 1
      if depth > max_depth
        '...'
      else
        x.map{|k,v| "#{keyenc(k)}=#{valenc(v, depth)}" }.join(' ')
      end
    end

    def keyenc(k)
      case k
      when String, Symbol then strenc(k)
      else
        strenc(k.inspect)
      end
    end

    def valenc(x, depth)
      case x
      when Hash           then objenc(x, depth)
      when Array          then arrenc(x, depth)
      when String, Symbol then strenc(x)
      when Numeric        then numenc(x)
      when Time, Date     then timeenc(x)
      when true           then '#t'
      when false          then '#f'
      when nil            then 'nil'
      else
        litenc(x)
      end
    end

    def objenc(x, depth)
      '{' + objenc_internal(x, depth) + '}'
    end

    def arrenc(a, depth)
      depth += 1
      # num + unit. Eg: 3ms
      if a.size == 2 && a.first.kind_of?(Numeric) && is_literal?(a.last.to_s)
        numenc(a.first) + ':' + strenc(a.last)
      elsif depth > max_depth
        '[...]'
      else
        '[' + a.map{|x| valenc(x, depth)}.join(' ') + ']'
      end
    end

    def strenc(s)
      s = s.to_s
      unless is_literal?(s)
        s = s.inspect
        unless s[1..-2].include?("'")
          s[0] = s[-1] = "'"
          s.gsub!('\"', '"')
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
Lines.use($stderr)
