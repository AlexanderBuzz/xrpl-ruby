# frozen_string_literal: true

module BinaryCodec

  class Uint < ComparableSerializedType
    # UInt64 fields that rippled renders in base 10 rather than as hex. They
    # hold MPToken amounts, where a hex string would be a needless surprise.
    BASE10_UINT64_FIELDS = %w[
      MaximumAmount
      OutstandingAmount
      MPTAmount
      LockedAmount
      ConfidentialOutstandingAmount
    ].freeze

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
        # Names for the fields that carry one: TransactionType and
        # LedgerEntryType (UInt16), TransactionResult (UInt8) and the
        # PermissionValue of a DelegateSet (UInt32). A name is never a valid
        # number, so the lookup cannot capture a numeric string.
        code = NAMED_VALUES.fetch(self, [])
                           .filter_map { |table| Definitions.instance.public_send(table)[value] }
                           .first
        return new(int_to_bytes(code, width)) if code

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

    # Returns the JSON representation of the Uint.
    # @return [Integer, String] The value.
    def to_json(_definitions = nil, _field_name = nil)
      # The fields that carry a name render it, the way rippled does. A code
      # without a name falls through and renders as the number.
      table = NAMED_FIELDS[_field_name]
      if table
        name = Definitions.instance.public_send(table).key(value_of)
        return name if name
      end

      # rippled renders the narrow unsigned integers as JSON numbers and UInt64
      # as a 16 digit hex string, because a UInt64 does not survive a round trip
      # through a JSON number. The MPToken amount fields are the exception to
      # that exception: they are UInt64 but carry a base 10 string.
      #
      # Everything wider than 8 bytes (Uint96 and up) is hash-like and stays
      # hex. Do not widen the numeric branch to cover it.
      val = value_of
      return val if self.class.width < 8
      return val.to_s if self.class.width == 8 && BASE10_UINT64_FIELDS.include?(_field_name)

      # Hex is unsigned, so a negative signed value has to wrap first.
      val += (1 << (self.class.width * 8)) if val < 0
      val.to_s(16).upcase.rjust(self.class.width * 2, '0')
    end
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

  class Uint
    # Which name tables a width accepts on the way in ...
    NAMED_VALUES = {
      Uint16 => %i[transaction_types ledger_entry_types],
      Uint8 => %i[transaction_results],
      Uint32 => %i[delegatable_permissions]
    }.freeze

    # ... and which field renders its value by name on the way out.
    NAMED_FIELDS = {
      'TransactionType' => :transaction_types,
      'LedgerEntryType' => :ledger_entry_types,
      'TransactionResult' => :transaction_results,
      'PermissionValue' => :delegatable_permissions
    }.freeze
  end

end