module Lines
  module Error; end

  class Loader
    class ParseError < StandardError; include Error; end

    DOT           = '.'
    EQUAL         = '='
    SPACE         = ' '
    OPEN_BRACKET  = '['
    SHUT_BRACKET  = ']'
    OPEN_BRACE    = '{'
    SHUT_BRACE    = '}'
    SINGLE_QUOTE  = "'"
    DOUBLE_QUOTE  = '"'
    BACKSLASH     = '\\'
    EOF           = nil

    ESCAPED_SINGLE_QUOTE = "\\'"
    ESCAPED_DOUBLE_QUOTE = '\"'

    LITERAL_MATCH = /[^=\s}\]]+/
    SINGLE_QUOTE_MATCH = /(?:\\.|[^'])*/
    DOUBLE_QUOTE_MATCH = /(?:\\.|[^"])*/

    NUM_MATCH = /-?(?:0|[1-9])\d*(?:\.\d+)?(?:[eE][+-]\d+)?/
    ISO8601_ZULU_CAPTURE = /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)Z$/
    NUM_CAPTURE = /^(#{NUM_MATCH})$/
    UNIT_CAPTURE = /^(#{NUM_MATCH}):(.+)/

    # Speeds parsing up a bit
    constants.each(&:freeze)

    def self.load(string)
      new.parse(string)
    end

    def parse(string)
      init(string.rstrip)
      inner_obj
    end

    protected

    def init(string)
      @string = string
      @pos = 0
      @c = @string[0]
    end

    def getc
      @pos += 1
      @c = @string[@pos]
    end

    def accept(char)
      if @c == char
        getc
        return true
      end
      false
    end

    def peek(num)
      @string[@pos+num]
    end

    def skip(num)
      @pos += num
      @c = @string[@pos]
    end

    def match(reg)
      @string.match(reg, @pos)
    end

    def expect(char)
      if !accept(char)
        fail "Expected '#{char}' but got '#{@c}'"
      end
    end

    def fail(msg)
      raise ParseError, "At #{@pos}, #{msg}"
    end

    def dbg(*x)
      #p [@pos, @c, @string[0..@pos]] + x
    end

    # Structures


    def inner_obj
      dbg :inner_obj
      # Shortcut for the '...' max_depth notation
      if @c == DOT && peek(1) == DOT && peek(2) == DOT
        expect DOT
        expect DOT
        expect DOT
        return {'...' => ''}
      end

      return {} if @c == EOF || @c == SHUT_BRACE

      # First pair
      k = key()
      expect EQUAL
      obj = {
        k => value()
      }

      while accept(SPACE)
        k = key()
        expect EQUAL
        obj[k] = value()
      end

      obj
    end

    def key
      dbg :key

      if @c == SINGLE_QUOTE
        single_quoted_string
      elsif @c == DOUBLE_QUOTE
        double_quoted_string
      else
        literal(false)
      end
    end

    def single_quoted_string
      dbg :single_quoted_string

      expect SINGLE_QUOTE
      md = match SINGLE_QUOTE_MATCH
      str = md[0].gsub ESCAPED_SINGLE_QUOTE, SINGLE_QUOTE
      skip md[0].size

      expect SINGLE_QUOTE
      str
    end

    def double_quoted_string
      dbg :double_quoted_string

      expect DOUBLE_QUOTE
      md = match DOUBLE_QUOTE_MATCH
      str = md[0].gsub ESCAPED_DOUBLE_QUOTE, DOUBLE_QUOTE
      skip md[0].size

      expect DOUBLE_QUOTE
      str
    end

    def literal(sub_parse)
      dbg :literal, sub_parse

      return "" unless ((md = match LITERAL_MATCH))

      literal = md[0]
      skip literal.size
      
      return literal unless sub_parse

      case literal
      when 'nil'
        nil
      when '#t'
        true
      when '#f'
        false
      when ISO8601_ZULU_CAPTURE
        Time.new($1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, '+00:00').utc
      when NUM_CAPTURE
        literal.index('.') ? Float(literal) : Integer(literal)
      when UNIT_CAPTURE
        num = $1.index('.') ? Float($1) : Integer($1)
        unit = $2
        [num, unit]
      else
        literal
      end
    end

    def value
      dbg :value

      case @c
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
      list.push value
      while accept(SPACE)
        list.push value
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
