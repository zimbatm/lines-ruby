module Lines
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
  # a tuple of (number, litteral) can be concatenated. Eg: (3, 'ms') => 3:ms
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

    constants.select{|x| x.kind_of?(String) }.each(&:freeze)

    def dump(obj) #=> String
      objenc_internal(obj)
    end

    # Used to introduce new ruby litterals.
    #
    # Usage:
    #
    #     Point = Struct.new(:x, :y)
    #     Lines.dumper.map(Point) do |p|
    #       "#{p.x}x#{p.y}"
    #     end
    #
    #     Lines.log msg: Point.new(3, 5)
    #     # logs: msg=3x5
    #
    def map(klass, &rule)
      @mapping[klass] = rule
    end

    # After a certain depth, arrays are replaced with [...] and objects with
    # {...}. Default is 4.
    attr_accessor :max_depth
    # TODO: rename to max_nesting

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
        x.map{|k,v| "#{keyenc(k)}=#{valenc(v, depth)}" }.join(SPACE)
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
      when Time           then timeenc(x)
      when Date           then dateenc(x)
      when true           then LIT_TRUE
      when false          then LIT_FALSE
      when nil            then LIT_NIL
      else
        litenc(x)
      end
    end

    def objenc(x, depth)
      OPEN_BRACE + objenc_internal(x, depth) + SHUT_BRACE
    end

    def arrenc(a, depth)
      depth += 1
      # num + unit. Eg: 3ms
      if a.size == 2 && a.first.kind_of?(Numeric) && is_literal?(a.last.to_s)
        "#{numenc(a.first)}:#{strenc(a.last)}"
      elsif depth > max_depth
        '[...]'
      else
        OPEN_BRACKET + a.map{|x| valenc(x, depth)}.join(' ') + SHUT_BRACKET
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
      strenc (class << x; self; end).ancestors.first.inspect
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
end
