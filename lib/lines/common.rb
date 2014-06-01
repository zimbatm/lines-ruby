module Lines
  NaN           = 0.0/0

  Infinity      = 1.0/0

  MinusInfinity = -Infinity

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
end
