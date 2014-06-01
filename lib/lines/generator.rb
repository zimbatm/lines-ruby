# -*- encoding : utf-8 -*-

require 'date'
require 'time'

require 'lines/common'

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
  module Generator; extend self
    STRING_ESCAPE_MATCH = /[\s"=:{}\[\]]/

    # max_nesting::
    #   After a certain depth, arrays are replaced with [...] and objects with
    #   {...}. Default is 4
    def generate(obj, opts={}) #=> String
      max_nesting = opts[:max_nesting] || 4
      objenc_internal(obj, max_nesting)
    end

    protected

    def objenc_internal(x, depth)
      depth -= 1
      if depth < 0
        DOT_DOT_DOT
      else
        x.map{|k,v| "#{keyenc(k)}=#{valenc(v, depth)}" }.join(SPACE)
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
      depth -= 1
      OPEN_BRACKET + if depth < 0
        DOT_DOT_DOT
      else
        a.map{|x| valenc(x, depth)}.join(SPACE)
      end + SHUT_BRACKET
    end

    def keyenc(s)
      s = s.to_s
      # Poor-man's escaping
      if s.include?(SINGLE_QUOTE)
        s.inspect
      elsif s.index(STRING_ESCAPE_MATCH)
        SINGLE_QUOTE +
          s.inspect[1..-2].gsub(ESCAPED_DOUBLE_QUOTE, DOUBLE_QUOTE) +
        SINGLE_QUOTE
      else
        s
      end
    end

    def strenc(s)
      s = s.to_s
      # Poor-man's escaping
      if s.include?(SINGLE_QUOTE)
        s.inspect
      elsif s.index(STRING_ESCAPE_MATCH) || s =~ NUM_CAPTURE || [LIT_TRUE, LIT_FALSE, LIT_NIL].include?(s)
        SINGLE_QUOTE +
          s.inspect[1..-2].gsub(ESCAPED_DOUBLE_QUOTE, DOUBLE_QUOTE) +
        SINGLE_QUOTE
      else
        s
      end
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
      strenc x.inspect
    rescue
      strenc (class << x; self; end).ancestors.first.inspect
    end

    def timeenc(t)
      t.utc.iso8601
    end

    def dateenc(d)
      d.iso8601
    end
  end
end
