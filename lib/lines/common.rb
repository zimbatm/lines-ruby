# -*- encoding : utf-8 -*-

module Lines
  module Error
    # Used to mark non-lines errors as being part of the library. This lets
    # a library user `rescue Lines::Error => ex` and catch all exceptions
    # comming from the lines library.
    def self.tag(obj)
      obj.extend Error
    end
  end

  class ParseError < StandardError; include Error; end
  #class LogicError < RuntimeError; include Error; end


  LIT_TRUE              = '#t'
  LIT_FALSE             = '#f'
  LIT_NIL               = 'nil'

  SPACE = ' '
  OPEN_BRACE = '{'
  SHUT_BRACE = '}'
  OPEN_BRACKET = '['
  SHUT_BRACKET = ']'
  SINGLE_QUOTE = "'"
  DOUBLE_QUOTE = '"'
end
