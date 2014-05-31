require 'date'
require 'time'

# Lines is an opinionated structured log format.
module Lines; extend self
  attr_writer :loader, :dumper

  # Parsing object. Responds to #load(string)
  def loader
    @loader ||= (
      require 'lines/loader'
      Loader
    )
  end

  # Serializing object. Responds to #dump(hash)
  def dumper
    @dumper ||= (
      require 'lines/dumper'
      Dumper.new
    )
  end

  # Parses a lines-formatted string
  def load(string)
    loader.load(string.to_s)
  end

  # Generates a lines-formatted string from the given object
  def dump(obj)
    dumper.dump(obj.to_h)
  end

  require 'securerandom'
  # A small utility to generate unique IDs that are as short as possible.
  #
  # It's useful to link contextes together
  #
  # See http://preshing.com/20110504/hash-collision-probabilities
  def id(collision_chance=1.0/10e9, over_x_messages=10e3)
    # Assuming that the distribution is perfectly random
    # how many bits do we need so that the chance of collision over_x_messages
    # is lower thant collision_chance ? 
    number_of_possible_numbers = (over_x_messages ** 2) / (2 * collision_chance)
    num_bytes = (Math.log2(number_of_possible_numbers) / 8).ceil
    SecureRandom.urlsafe_base64(num_bytes)
  end
end
