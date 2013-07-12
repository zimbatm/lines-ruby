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
    rule(:line) {
      (pair >> (space >> pair).repeat).as(:object)
    }

    rule(:pair) {
      (
         string.as(:key) >>
         str('=') >>
         value.as(:val)
      ).as(:pair)
    }

    rule(:string) {
      singlequoted_string | doublequoted_string | literal
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

    rule(:literal) {
      match['^:=\s{}\[\]\'"'].repeat.as(:literal)
    }

    rule(:value) {
      object |
      list |
      str('#t').as(:true) |
      str('#f').as(:false) |
      str('nil').as(:nil) |
      number |
      time |
      unit |
      string
    }

    rule(:object) {
      str('{') >>
      (
        str('.').repeat(3).as(:max_depth_object) |
        (pair >> (space >> pair).repeat).maybe.as(:object)
      ) >>
      str('}')
    }

    rule(:space) { match(' ').repeat(1) }

    rule(:list) {
      str('[') >> 
      (value >> (space >> value).repeat).maybe.as(:list) >>
      str(']')
    }

    rule(:number) {
      (
        str('-').maybe >> (
          str('0') | (match['1-9'] >> digit.repeat)
        ) >> (
          str('.') >> digit.repeat(1)
        ).maybe >> (
          match('[eE]') >> (str('+') | str('-')).maybe >> digit.repeat(1)
        ).maybe
      ).as(:number)
    }

    rule(:time) {
      digit.repeat(4) >> str('-') >>
      digit.repeat(2) >> str('-') >>
      digit.repeat(2) >> str('T') >>
      digit.repeat(2) >> str(':') >>
      digit.repeat(2) >> str(':') >>
      digit.repeat(2) >> str('Z')
    }

    rule(:unit) {
      (number >> str(':') >> literal).as(:unit)
    }

    # Other
    rule(:digit) { match['0-9'] }
    
    root(:line)
  end

  class Transformer < Parslet::Transform
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
    rule(max_depth_object: simple(:mdo)) { {'...' => ''} }

    rule(time: { year: simple(:ye), month: simple(:mo), day: simple(:da), hour: simple(:ho), minute: simple(:min), second: simple(:sec)}) {
      Time.new(ye.to_i, mo.to_i, da.to_i, ho.to_i, min.to_i, sec.to_i, "+00:00")
    }

    rule(singlequoted_string: simple(:sqs)) {
      sqs.to_s.gsub("\\'", "'")
    }

    rule(doublequoted_string: simple(:dqs)) {
      dqs.to_s.gsub('\\"', '"')
    }

    # Sub-parsing of the literal
    rule(literal: simple(:st)) {
      st.to_s
    }

    rule(literal: subtree(:st2)) {
      st2.join
    }

    rule(number: simple(:nb)) {
      nb.match(/[eE\.]/) ? Float(nb) : Integer(nb)
    }

    rule(nil: simple(:ni)) { nil }
    rule(true: simple(:tr)) { true }
    rule(false: simple(:fa)) { false }
  end
end
