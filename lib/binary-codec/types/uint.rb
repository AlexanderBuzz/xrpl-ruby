# frozen_string_literal: true

module BinaryCodec

  class Uint < ComparableSerializedType
    class << self
      attr_reader :width
    end

    def initialize(byte_buf = nil)
      @bytes = byte_buf || Array.new(self.class.width, 0)
    end

    def self.from(value)
      return value if value.is_a?(self)

      if value.is_a?(String)
        return new(int_to_bytes(value.to_i, width))
      end

      if value.is_a?(Integer)
        return new(int_to_bytes(value, width))
      end

      raise StandardError, "Cannot construct #{self} from the value given"
    end

    def value_of
      @bytes.reduce(0) { |acc, byte| (acc << 8) + byte }
    end
  end

  class Uint8 < Uint
    # Uint8 is a 1-byte unsigned integer
    @width = 1
  end

  class Uint16 < Uint
    # Uint16 is a 2-byte unsigned integer
    @width = 2
  end

  class Uint32 < Uint
    # Uint32 is a 4-byte unsigned integer
    @width = 4
  end

  class Uint64 < Uint
    # Uint64 is an 8-byte unsigned integer
    @width = 8
  end

end