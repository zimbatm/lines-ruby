require 'strscan'

require 'lines/common'

module Lines
  class Parser
    EQUAL                 = '='
    BACKSLASH             = '\\'
    
    ESCAPED_SINGLE_QUOTE  = "\\'"
    ESCAPED_DOUBLE_QUOTE  = '\"'

    DOT_DOT_DOT           = '...'
    DOT_DOT_DOT_MATCH     = /\.\.\./

    LITERAL_MATCH         = /[^=\s}\]]+/
    SINGLE_QUOTE_MATCH    = /(?:\\.|[^'])*/
    DOUBLE_QUOTE_MATCH    = /(?:\\.|[^"])*/

    NUM_MATCH             = /-?(?:0|[1-9])\d*(?:\.\d+)?(?:[eE][+-]\d+)?/
    ISO8601_ZULU_CAPTURE  = /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)Z$/
    NUM_CAPTURE           = /^(#{NUM_MATCH})$/

    constants.each(&:freeze)

    def self.parse(string, opts={})
      new.parse(string, opts)
    end

    def parse(string, opts)
      init(string)
      inner_obj
    end

    protected

    def init(string)
      @s = StringScanner.new(string)
      @c = string[0]
    end

    def accept(char)
      if @s.peek(1) == char
        @s.pos += 1
        return true
      end
      false
    end

    def skip(num)
      @s.pos += num
    end

    def expect(char)
      if !accept(char)
        fail "Expected '#{char}' but got '#{@s.peek(1)}'"
      end
    end

    def fail(msg)
      raise ParseError, "At #{@s}, #{msg}"
    end

    def dbg(*x)
      #p [@s] + x
    end

    # Structures


    def inner_obj
      dbg :inner_obj
      # Shortcut for the '...' max_depth notation
      if @s.scan(DOT_DOT_DOT_MATCH)
        return {DOT_DOT_DOT => ''}
      end

      return {} if @s.eos? || @s.peek(1) == SHUT_BRACE

      # First pair
      k = key()
      expect EQUAL
      obj = {
        k => value()
      }

      while accept(SPACE) and !@s.eos?
        k = key()
        expect EQUAL
        obj[k] = value()
      end

      obj
    end

    def key
      dbg :key

      case @s.peek(1)
      when SINGLE_QUOTE
        single_quoted_string
      when DOUBLE_QUOTE
        double_quoted_string
      else
        literal(false)
      end
    end

    def single_quoted_string
      dbg :single_quoted_string

      expect SINGLE_QUOTE
      str = @s.scan(SINGLE_QUOTE_MATCH).
        gsub(ESCAPED_SINGLE_QUOTE, SINGLE_QUOTE)
      expect SINGLE_QUOTE
      str
    end

    def double_quoted_string
      dbg :double_quoted_string

      expect DOUBLE_QUOTE
      str = @s.scan(DOUBLE_QUOTE_MATCH).
        gsub(ESCAPED_DOUBLE_QUOTE, DOUBLE_QUOTE)
      expect DOUBLE_QUOTE
      str
    end

    def literal(sub_parse)
      dbg :literal, sub_parse

      literal = @s.scan LITERAL_MATCH

      return "" unless literal
      
      return literal unless sub_parse

      case literal
      when LIT_NIL
        nil
      when LIT_TRUE
        true
      when LIT_FALSE
        false
      when ISO8601_ZULU_CAPTURE
        Time.new($1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, '+00:00').utc
      when NUM_CAPTURE
        literal.index('.') ? Float(literal) : Integer(literal)
      else
        literal
      end
    end

    def value
      dbg :value

      case @s.peek(1)
      when OPEN_BRACKET
        list
      when OPEN_BRACE
        object
      when DOUBLE_QUOTE
        double_quoted_string
      when SINGLE_QUOTE
        single_quoted_string
      else
        literal(:sub_parse)
      end
    end

    def list
      dbg :list

      list = []
      expect(OPEN_BRACKET)
      list.push value()
      while accept(SPACE)
        list.push value()
      end
      expect(SHUT_BRACKET)
      list
    end

    def object
      dbg :object

      expect(OPEN_BRACE)
      obj = inner_obj
      expect(SHUT_BRACE)
      obj
    end
  end
end
