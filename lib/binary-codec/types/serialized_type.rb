# frozen_string_literal: true

require_relative '../../core/core'

module BinaryCodec
  class SerializedType

    attr_reader :bytes

    def initialize(bytes = nil)
      raise NotImplementedError, "#{self.class} is an abstract class and cannot be instantiated"
    end

    def self.from(value)
      raise NotImplementedError, 'from not implemented'
    end

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
      puts "ST to_hex / to_bytes: #{@bytes}"
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

    # Represent object as a string (hexadecimal form)
    def to_s
      to_hex
    end

    def self.get_type_by_name(name)
      type_map = {
        "AccountID" => AccountId,
        "Amount" => Amount,
        "Blob" => Blob,
        "Currency" => Currency,
        "Hash128" => Hash128,
        "Hash160" => Hash160,
        "Hash256" => Hash256,
        #"PathSet" => PathSet,
        #"STArray" => STArray,
        "STObject" => STObject,
        "UInt8" => Uint8,
        "UInt16" => Uint16,
        "UInt32" => Uint32,
        "UInt64" => Uint64,
        #"Vector256" => Vector256
      }

      unless type_map.key?(name)
        raise "unsupported type #{name}"
      end

      # Return class
      type_map[name]
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