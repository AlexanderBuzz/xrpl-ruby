# frozen_string_literal: true

module BinaryCodec

  class Uint < ComparableSerializedType
    # Returns the width of the Uint type in bytes.
    # @return [Integer] The width.
    def self.width
      @width
    end

    def initialize(byte_buf = nil)
      super(byte_buf || Array.new(self.class.width, 0))
    end

    # Creates a new Uint instance from a value.
    # @param value [Uint, String, Integer] The value to convert.
    # @return [Uint] The created instance.
    def self.from(value)
      return value if value.is_a?(self)

      if value.is_a?(String)
        # Handle hex strings or numeric strings
        if valid_hex?(value) && value.length == self.width * 2
          return new(hex_to_bytes(value))
        end
        return new(int_to_bytes(value.to_i, width))
      end

      if value.is_a?(Integer)
        return new(int_to_bytes(value, width))
      end

      raise StandardError, "Cannot construct #{self} from the value given"
    end

    # Creates a Uint instance from a parser.
    # @param parser [BinaryParser] The parser to read from.
    # @param _hint [Integer, nil] Unused hint.
    # @return [Uint] The created instance.
    def self.from_parser(parser, _hint = nil)
      new(parser.read(width))
    end

    # Returns the numeric value of the Uint.
    # @return [Integer] The numeric value.
    def value_of
      @bytes.reduce(0) { |acc, byte| (acc << 8) + byte }
    end

    # Compares this Uint to another Uint.
    # @param other [Uint] The other Uint to compare to.
    # @return [Integer] Comparison result (-1, 0, or 1).
    def compare_to(other)
      value_of <=> other.value_of
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

  class Uint96 < Uint
    # Uint96 is a 12-byte unsigned integer
    @width = 12
  end

  class Uint128 < Uint
    # Uint128 is a 16-byte unsigned integer
    @width = 16
  end

  class Uint160 < Uint
    # Uint160 is a 20-byte unsigned integer
    @width = 20
  end

  class Uint192 < Uint
    # Uint192 is a 24-byte unsigned integer
    @width = 24
  end

  class Uint256 < Uint
    # Uint256 is a 32-byte unsigned integer
    @width = 32
  end

  class Uint384 < Uint
    # Uint384 is a 48-byte unsigned integer
    @width = 48
  end

  class Uint512 < Uint
    # Uint512 is a 64-byte unsigned integer
    @width = 64
  end

  class Int32 < Uint
    @width = 4
    # Returns the numeric value of the Int32.
    # @return [Integer] The signed 32-bit value.
    def value_of
      val = super
      val > 0x7FFFFFFF ? val - 0x100000000 : val
    end

    # Creates a new Int32 instance from a value.
    # @param value [Int32, Integer] The value to convert.
    # @return [Int32] The created instance.
    def self.from(value)
      return value if value.is_a?(self)
      if value.is_a?(Integer)
        # Ensure it fits in 32-bit signed
        if value < -2147483648 || value > 2147483647
          raise StandardError, "Value #{value} out of range for Int32"
        end
        # Convert to unsigned 32-bit for storage
        u_val = value < 0 ? value + 0x100000000 : value
        return new(int_to_bytes(u_val, 4))
      end
      super(value)
    end
  end

  class Int64 < Uint
    @width = 8
    # Returns the numeric value of the Int64.
    # @return [Integer] The signed 64-bit value.
    def value_of
      val = super
      val > 0x7FFFFFFFFFFFFFFF ? val - 0x10000000000000000 : val
    end

    # Creates a new Int64 instance from a value.
    # @param value [Int64, Integer] The value to convert.
    # @return [Int64] The created instance.
    def self.from(value)
      return value if value.is_a?(self)
      if value.is_a?(Integer)
        if value < -9223372036854775808 || value > 9223372036854775807
          raise StandardError, "Value #{value} out of range for Int64"
        end
        u_val = value < 0 ? value + 0x10000000000000000 : value
        return new(int_to_bytes(u_val, 8))
      end
      super(value)
    end
  end

end