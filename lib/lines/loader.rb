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
  #
  # TODO:
  #   ISO8601 dates
  class Parser < Parslet::Parser

    rule(:spaces) { match(' ').repeat(1) }
    rule(:spaces?) { spaces.maybe }

    rule(:digit) { match['0-9'] }

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

    rule(:singlequoted_string) {
      str("'") >> (
        str('\\') >> any | str("'").absent? >> any
      ).repeat.as(:string) >> str("'")
    }

    rule(:doublequoted_string) {
      str('"') >> (
        str('\\') >> any | str('"').absent? >> any
      ).repeat.as(:string) >> str('"')
    }

    rule(:simple_string) {
      match['a-zA-Z_\-:'].repeat.as(:string)
    }

    rule(:string) {
      singlequoted_string | doublequoted_string | simple_string
    }

    rule(:array) {
      str('[') >> spaces? >>
      (value >> (spaces >> value).repeat).maybe.as(:array) >>
      spaces? >> str(']')
    }

    rule(:object) {
      str('{') >> spaces? >>
      (entry >> (spaces >> entry).repeat).maybe.as(:object) >>
      spaces? >> str('}')
    }

    rule(:key) {
      match['a-zA-Z0-9_'].repeat
    }

    rule(:value) {
      str('#t').as(:true) | str('#f').as(:false) |
      str('nil').as(:nil) |
      object | array |
      number | time |
      string
    }

    rule(:entry) {
      (
         key.as(:key) >>
         str('=') >>
         value.as(:val)
      ).as(:entry)
    }

    rule(:top) { spaces? >> (entry >> (spaces >> entry).repeat).maybe.as(:object) >> spaces? }
    #rule(:top) { (digit >> digit).as(:digit) }
    #rule(:top) { time }

    root(:top)
  end

  class Transformer < Parslet::Transform

    class Entry < Struct.new(:key, :val); end

    rule(array: subtree(:ar)) {
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
      end.inject({}) { |h, e|
        h[e[:entry][:key].to_s] = e[:entry][:val]; h
      }
    }

    # rule(entry: { key: simple(:ke), val: simple(:va) }) {
    #   Entry.new(ke.to_s, va)
    # }

    rule(time: { year: simple(:ye), month: simple(:mo), day: simple(:da), hour: simple(:ho), minute: simple(:min), second: simple(:sec)}) {
      Time.new(ye.to_i, mo.to_i, da.to_i, ho.to_i, min.to_i, sec.to_i, "+00:00")
    }

    rule(string: simple(:st)) {
      st.to_s
    }

    rule(number: simple(:nb)) {
      nb.match(/[eE\.]/) ? Float(nb) : Integer(nb)
    }

    rule(nil: simple(:ni)) { nil }
    rule(true: simple(:tr)) { true }
    rule(false: simple(:fa)) { false }
  end
end
