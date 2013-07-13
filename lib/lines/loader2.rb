module Lines
  module Error; end

  class Loader2
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

    END_OF_LITERAL = [EQUAL, SPACE, OPEN_BRACE, SHUT_BRACE, OPEN_BRACKET, SHUT_BRACKET, EOF]

    NUM_MATCH = /-?(?:0|[1-9])\d*(?:\.\d+)?(?:[eE][+-]\d+)?/
    ISO8601_ZULU_CAPTURE = /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)Z$/
    NUM_CAPTURE = /^(#{NUM_MATCH})$/
    UNIT_CAPTURE = /^(#{NUM_MATCH}):(.+)/

    def self.load(string)
      new.parse(string)
    end

    def parse(string)
      init(string)
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

    def expect(char)
      if !accept(char)
        fail "Expected '#{char}' but got '#{@c}'"
      end
    end

    def expect_not(char)
      if accept(char)
        fail "Didn't expect '#{char}'"
      end
    end

    def fail(msg)
      raise ParseError, "At #{@pos}, #{msg}"
    end


    # Structures


    def inner_obj
      # Shortcut for the '...' max_depth notation
      if @c == DOT && peek(1) == DOT && peek(2) == DOT
        expect(DOT)
        expect(DOT)
        expect(DOT)
        return {'...' => ''}
      end

      obj = {}
      while @c != EOF && @c != SHUT_BRACE
        
        k = key()
        expect(EQUAL)
        obj[k] = value()
        accept(SPACE)
      end
      obj
    end

    def key
      if @c == SINGLE_QUOTE
        quoted_string(SINGLE_QUOTE)
      elsif @c == DOUBLE_QUOTE
        quoted_string(DOUBLE_QUOTE)
      else
        literal(false)
      end
    end

    def quoted_string(quote_type)
      expect(quote_type)
      start_pos = @pos
      while @c != quote_type
        accept(BACKSLASH)
        getc
        fail "didn't expect EOF" if @c == EOF
      end
      str = @string[start_pos..@pos-1].gsub(BACKSLASH + quote_type, quote_type)
      expect(quote_type)
      str
    end

    def literal(sub_parse)
      start_pos = @pos
      
      while !END_OF_LITERAL.include?(@c)
        getc
      end

      if start_pos == @pos
        literal = ""
      else
        literal = @string[start_pos..@pos-1]
      end
      
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
      case @c
      when OPEN_BRACKET
        list
      when OPEN_BRACE
        object
      when DOUBLE_QUOTE
        quoted_string(DOUBLE_QUOTE)
      when SINGLE_QUOTE
        quoted_string(SINGLE_QUOTE)
      else
        literal(true)
      end
    end

    def list
      list = []
      expect(OPEN_BRACKET)
      list.push value
      expect(SHUT_BRACKET)
      list
    end

    def object
      expect(OPEN_BRACE)
      obj = inner_obj
      expect(SHUT_BRACE)
      obj
    end
  end
end
