begin
  require 'parslet'
rescue LoadError
  warn "lines/loader depends on parslet"
  raise
end

# http://zerowidth.com/2013/02/24/parsing-toml-in-ruby-with-parslet.html
module Lines
  module Error; end
  module ParseError; include Error; end
  module Loader; extend self
    def load(s)
      parser = Parser.new
      transformer = Transformer.new

      tree = parser.parse(s)
      #puts; p tree; puts
      transformer.apply(tree)
    rescue Parslet::ParseFailed => ex
      # Mark as being part of the Lines library
      ex.extend ParseError
      raise
    end
  end

  # Mostly copied over from the JSON example:
  #   https://github.com/kschiess/parslet/blob/master/example/json.rb
  class Parser < Parslet::Parser
    rule(:space) { match(' ') }

    rule(:literal) {
      match['^=\s{}\[\]\'"'].repeat
    }

    rule(:line) {
      (pair >> (space >> pair).repeat).as(:object)
    }

    rule(:singlequoted_string) {
      str("'") >> (
        str('\\') >> any | str("'").absent? >> any
      ).repeat.as(:singlequoted_string) >> str("'")
    }

    rule(:doublequoted_string) {
      str('"') >> (
        str('\\') >> any | str('"').absent? >> any
      ).repeat.as(:doublequoted_string) >> str('"')
    }

    rule(:string) {
      singlequoted_string | doublequoted_string
    }

    rule(:pair) {
      (
         (string | literal.as(:key_literal)).as(:key) >>
         str('=') >>
         value.as(:val)
      ).as(:pair)
    }

    rule(:value) {
      object |
      list |
      string |
      literal.as(:value_literal)
    }

    rule(:object) {
      str('{') >>
      (
        str('.').repeat(3).as(:max_depth_object) |
        (pair >> (space >> pair).repeat).maybe.as(:object)
      ) >>
      str('}')
    }

    rule(:list) {
      str('[') >> 
      (value >> (space >> value).repeat).maybe.as(:list) >>
      str(']')
    }
    
    root(:line)
  end

  class Transformer < Parslet::Transform
    rule(object: subtree(:ob)) {
      case ob
      when nil
        []
      when Array
        ob
      else
        [ob]
      end.inject({}) do |h, e|
        h[e[:pair][:key]] = e[:pair][:val]
        h
      end
    }

    rule(list: subtree(:ar)) {
      case ar
      when nil
        []
      when Array
        ar
      else
        [ar]
      end
    }
    rule(max_depth_object: simple(:mdo)) { {'...' => ''} }

    rule(singlequoted_string: simple(:sqs)) {
      sqs.to_s.gsub("\\'", "'")
    }

    rule(doublequoted_string: simple(:dqs)) {
      dqs.to_s.gsub('\\"', '"')
    }

    # Key literal is never parsed for values
    rule(key_literal: simple(:klit)) {
      klit.to_s
    }

    NUM_REG = /-?(?:0|[1-9])\d*(?:\.\d+)?(?:[eE][+-]\d+)?/

    # Sub-parsing of the literal when it's a value
    rule(value_literal: simple(:vlit)) {
      str = vlit.to_s
      case str
      when 'nil'
        nil
      when '#t'
        true
      when '#f'
        false
      when /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)Z$/
        Time.new($1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, '+00:00').utc
      when /^#{NUM_REG}$/
        str.index('.') ? Float(str) : Integer(str)
      when /^(#{NUM_REG}):(.*)$/
        num = $1.index('.') ? Float($1) : Integer($1)
        unit = $2
        [num, unit]
      else
        str
      end
    }

    # Empty literal is an empty array
    rule(key_literal: subtree(:klit2)) {
      klit2.join
    }

    rule(value_literal: subtree(:vlit2)) {
      vlit2.join
    }

    
  end
end
