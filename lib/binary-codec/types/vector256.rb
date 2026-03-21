# frozen_string_literal: true

module BinaryCodec
  class Vector256 < SerializedType
    def initialize(bytes = nil)
      super(bytes || [])
    end

    # Creates a new Vector256 instance from a value.
    # @param value [Vector256, String, Array<String>] The value to convert.
    # @return [Vector256] The created instance.
    def self.from(value)
      return value if value.is_a?(Vector256)

      if value.is_a?(String)
        return Vector256.new(hex_to_bytes(value))
      end

      if value.is_a?(Array)
        bytes = []
        value.each do |item|
          hash = Hash256.from(item)
          bytes.concat(hash.to_bytes)
        end
        return Vector256.new(bytes)
      end

      raise StandardError, "Cannot construct Vector256 from #{value.class}"
    end

    # Creates a Vector256 instance from a parser.
    # @param parser [BinaryParser] The parser to read from.
    # @param size_hint [Integer] The expected total size in bytes.
    # @return [Vector256] The created instance.
    def self.from_parser(parser, size_hint = nil)
      bytes = []
      num_hashes = size_hint / 32
      num_hashes.times do
        bytes.concat(parser.read(32))
      end
      Vector256.new(bytes)
    end

    def to_json(_definitions = nil, _field_name = nil)
      parser = BinaryParser.new(to_hex)
      result = []
      until parser.end?
        result << bytes_to_hex(parser.read(32))
      end
      result
    end
  end
end
