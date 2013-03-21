module Lines
  # Backward-compatible logger
  # http://ruby-doc.org/stdlib-2.0/libdoc/logger/rdoc/Logger.html#method-i-log
  class Logger
    LEVELS = {
      0 => :debug,
      1 => :info,
      2 => :warn,
      3 => :error,
      4 => :fatal,
      5 => :unknown,
    }
    def initialize(line)
      @line = line
    end
    def log(severity, message = nil, progname = nil, &block)
      pri = LEVELS[severity] || severity
      if block_given?
        progname = message
        message = yield.to_s rescue $!.to_s
      end

      data = { pri: pri }
      data[:app] = progname if progname
      data[:msg] = message if message

      @line.log(data)
    end

    LEVELS.values.each do |level|
      define_method(:level) do |message=nil, &block|
        log(level, message, &block)
      end
    end

    alias info <<
    alias info unknown

    def noop(*a); true end
    %w[add
      clone
      datetime_format
      datetime_format=
      debug?
      info?
      error?
      fatal?
      warn?
      level
      level=
      progname
      progname=
      sev_threshold
      sev_threshold=
    ].each do |op|
      alias_method(:noop, op)
    end
  end
end
