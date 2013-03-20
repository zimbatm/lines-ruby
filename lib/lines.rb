require 'date'
require 'time'
require 'securerandom'
require 'forwardable'

# https://github.com/headius/ruby-atomic

# Lines is an opinionated structured log format and a library
# inspired by Slogger.
#
# Don't use log levels. They limit the reasoning of the developer.
# Log everything in development AND production.
# Logs should be easy to read, grep and parse.
# Logging something should never fail.
# Use syslog.
#
# Example:
#
#     log(msg: "Oops !")
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
#     Lines.context(:foo => :bar) do
#       Lines.log(:sadfasdf => 3)
#     end
module Lines; extend self
  def outputters; @outputters ||= []; end

  def use(*outputs)
    outputters.replace(outputs.map{|o| to_outputter o})
  end

  def log(obj)
    obj = sanitize_obj(obj)
    outputters.each{|out| out.output(obj) }
    obj
  end

  # TODO: define exception format
  #
  # Usage:
  #
  #   begin
  #      raise
  #   rescue Lines.rescue => ex
  #      puts "This exception has been logged"
  #   end
  def rescue(includes=[StandardError], ex=$!)
    if (ex.class.ancestors & accepted).size > 0
      log(ex)
      ex
    end
  end

  # TODO: make these work
  def ctx(opts = {}, &block)
    Context.new(self, opts, &block)
  end

  # A backward-compatibility logger
  def logger
    @logger ||= (
      require "lines/logger"
      Logger.new(self)
    )
  end

  protected

  def sanitize_obj(obj)
    obj = obj.to_h if obj.respond_to?(:to_h)
    obj = {msg: obj.inspect} unless obj.kind_of?(Hash)
    obj
  end

  def to_outputter(out)
    return out if out.respond_to?(:output)

    case out
    when :stdout
      out = $stdout
    when :stderr
      out = $stderr
    end

    case out
    when IO
      StreamOutputter.new(out)
    when :syslog, Syslog
      SyslogOutputter.new
    else
      if out.respond_to?(:write)
        StreamOutputter.new(out)
      else
        raise ArgumentError, "unknown outputter #{out.inspect}"
      end
    end
  end

  class Context
    extend Forwardable

    attr_reader :line
    def_delegators :line, :log

    def initialize(line, opts, &block)
      @line = line
      @opts = opts
      yield(self) if block_given?
    end

    def log(opts); line.log(@opts.merge(opts)) end
  end

  class StreamOutputter
    LF = "\n".freeze
    # stream must accept a #write(str) message
    def initialize(stream = $stderr)
      @stream = stream
    end

    def output(obj)
      str = Dumper.dump(obj)
      stream.write str + LF
    end

    protected

    attr_reader :stream
  end

  require 'syslog'
  class SyslogOutputter
    PRI2SYSLOG = {
      debug:    Syslog::LOG_DEBUG,
      info:     Syslog::LOG_INFO,
      warn:     Syslog::LOG_WARNING,
      warning:  Syslog::LOG_WARNING,
      err:      Syslog::LOG_ERR,
      error:    Syslog::LOG_ERR,
      crit:     Syslog::LOG_CRIT,
      critical: Syslog::LOG_CRIT,
    }

    def initialize(syslog = Syslog, app_name=nil)
      @app_name = app_name
      @syslog = syslog
      prepare_syslog
    end

    def output(obj)
      obj = obj.dup
      obj.delete(:pid) # It's going to be part of the message
      obj.delete(:at)  # Also part of the message
      obj.delete(:app) # Also, but make sure syslog is configured right

      level = extract_pri(obj)
      str = Dumper.dump(obj)

      syslog.log(level, str)
    end

    protected

    attr_reader :app_name
    attr_reader :syslog

    def prepare_syslog
      unless syslog.opened?
        # Did you know ? app_name is detected by syslog if nil
        syslog.open(app_name,
                    Syslog::LOG_PID & Syslog::LOG_CONS & Syslog::LOG_NDELAY,
                    Syslog::LOG_USER)
      end
    end

    def extract_pri(h)
      pri = (h.delete(:pri) || h.delete('pri')).to_s.downcase
      PRI2SYSLOG[pri] || PRI2SYSLOG[:info]
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
  #
  # TODO: Numbers need to be better specified. I want to support readable
  #       notations like 10e9 and 10'000.445
  #
  module Dumper; extend self
    def dump(obj) #=> String
      objenc_internal(obj)
    end

    def map(klass, &rule)
      @mapping ||= {}
      @mapping[klass] = rule
    end
    
    protected

    attr_reader :mapping

    def valenc(x)
      case x
      when Hash       then objenc(x)
      when Array      then arrenc(x)
      when String     then strenc(x)
      when Numeric    then numenc(x)
      when Time, Date then timeenc(x)
      when true       then "#t"
      when false      then "#f"
      when nil        then "nil"
      else
        klass = (x.class.ancestors & mapping.keys).first
        if klass
          mapping[klass].call(x)
        else
          strenc(x.inspect)
        end
      end
    end

    def objenc_internal(x)
      x.map{|k,v| keyenc(k).to_s + '=' + valenc(v).to_s }.join(' ')
    end

    def objenc(x)
      '{' + objenc_internal(x) + '}'
    end

    def arrenc(a)
      # num + unit. Eg: 3ms
      if a.size == 2 && a.first.kind_of?(Numeric) && is_literal?(a.last.to_s)
        numenc(a.first) + strenc(a.last)
      else
        '[' + a.map{|x| valenc(x)}.join(' ') + ']'
      end
    end

    def timeenc(t)
      t.iso8601
    end

    def keyenc(k)
      case k
      when String, Symbol then strenc(k)
      else
        strenc(k.inspect)
      end
    end

    # TODO: Support shorter syntaxes like 10e9 and separators like 10_000
    def numenc(n)
      case n
      when Float
        "%.3f" % n
      else
        n.to_s
      end
    end

    def is_literal?(s)
      !s.index(/[ '"]/)
    end

    # TODO: Single-quote espace if possible
    def strenc(s)
      s = s.to_s
      s = s.inspect unless is_literal?(s)
    end
  end

  module UniqueIDs
    # A small utility to generate unique IDs that are as short as possible.
    #
    # It's useful to link contextes together
    def id(collision_chance=10e9, over_x_messages=10e3)
      # Assuming that the distribution is perfectly random
      # how many bits do we need so that the chance of collision over_x_messages
      # is higher thant collision_chance ?

      # FIXME: This algo is wrong. Use http://preshing.com/20110504/hash-collision-probabilities
      bits = Math.log2(collision_chance * over_x_messages)
      num_bytes = (bits / 8).ceil
      SecureRandom.urlsafe_base64(num_bytes)
    end
  end
  extend UniqueIDs
end
