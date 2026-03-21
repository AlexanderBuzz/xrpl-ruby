# frozen_string_literal: true

module BinaryCodec
  class SerializedType

    attr_reader :bytes

    # Initializes a new SerializedType instance.
    # @param bytes [Array<Integer>, nil] The byte array representing the serialized data.
    def initialize(bytes = nil)
      @bytes = bytes
    end

    # Creates a new instance of the type from a value.
    # @param value [Object] The value to convert.
    # @return [SerializedType] The created instance.
    def self.from(value)
      raise NotImplementedError, 'from not implemented'
    end

    # Creates an instance of the type from a parser.
    # @param parser [BinaryParser] The parser to read from.
    # @param size_hint [Integer, nil] Optional size hint.
    # @return [SerializedType] The created instance.
    def self.from_parser(parser, size_hint = nil)
      raise NotImplementedError, 'from_parser not implemented'
    end

    # Check if this is needed
    def self.from_json(json)
      raise NotImplementedError, 'from_parser not implemented'
    end

    # Check if this is needed
    def self.from_hex(hex)
      self.from_bytes(hex_to_bytes(hex))
    end

    # Check if this is needed
    def self.from_bytes(bytes)
      new(bytes)
    end

    # Puts the serialized data into a byte sink.
    # @param sink [Object] The sink to put bytes into.
    def to_byte_sink(sink)
      sink.put(to_bytes)
    end

    # Serialize the given value into bytes
    # This method must be implemented in the subclasses
    # @return [Array<Integer>] - Byte array representing the serialized data
    def to_bytes
      @bytes
    end

    # Convert to a hex string
    # @return [String] - Hexadecimal representation of the serialized data
    def to_hex
      bytes_to_hex(to_bytes)
    end

    # Deserialize instance data and convert it to JSON string
    #
    # @param _definitions [Hash] - Definitions for serialization
    # @param _field_name [String] - Field name for serialization
    # @return [String] - JSON representation of the serialized data
    def to_json(_definitions = nil, _field_name = nil)
      to_hex
    end

    # Returns the value of the serialized type
    # @return [Object] - The value of the serialized type
    def value_of
      @bytes
    end

    # Returns the class for a given type name.
    # @param name [String] The name of the type.
    # @return [Class] The class associated with the type name.
    def self.get_type_by_name(name)
      case name
      when "AccountID" then AccountId
      when "Amount" then Amount
      when "Blob" then Blob
      when "Currency" then Currency
      when "Hash128" then Hash128
      when "Hash160" then Hash160
      when "Hash192" then Hash192
      when "Hash256" then Hash256
      when "STArray" then STArray
      when "STObject" then STObject
      when "UInt8" then Uint8
      when "UInt16" then Uint16
      when "UInt32" then Uint32
      when "UInt64" then Uint64
      when "UInt96" then Uint96
      when "UInt128" then Uint128
      when "UInt160" then Uint160
      when "UInt192" then Uint192
      when "UInt256" then Uint256
      when "UInt384" then Uint384
      when "UInt512" then Uint512
      when "Int32" then Int32
      when "Int64" then Int64
      when "PathSet" then PathSet
      when "Vector256" then Vector256
      when "XChainBridge" then XChainBridge
      when "Issue" then Issue
      when "Transaction" then Blob
      when "LedgerEntry" then Blob
      when "Validation" then Blob
      when "Metadata" then Blob
      else
        raise "unsupported type #{name}"
      end
    end

  end

  class ComparableSerializedType < SerializedType

    # Compare if `self` is less than `other`
    def lt(other)
      compare_to(other) < 0
    end

    # Compare if `self` is equal to `other`
    def eq(other)
      compare_to(other) == 0
    end

    # Compare if `self` is greater than `other`
    def gt(other)
      compare_to(other) > 0
    end

    # Compare if `self` is greater than or equal to `other`
    def gte(other)
      compare_to(other) >= 0
    end

    # Compare if `self` is less than or equal to `other`
    def lte(other)
      compare_to(other) <= 0
    end

    # Overload this method in subclasses to define comparison logic
    #
    # @param other [Object] - The object to compare `self` to
    # @return [Integer] - Returns -1, 0, or 1 depending on the comparison
    def compare_to(other)
      raise NotImplementedError, "Cannot compare #{self} and #{other}"
    end
  end

end