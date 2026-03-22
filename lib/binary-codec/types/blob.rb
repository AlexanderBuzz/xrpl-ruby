# frozen_string_literal: true

module BinaryCodec
  class Blob < SerializedType

    def initialize(byte_buf = nil)
      super(byte_buf || [])
    end

    # Creates a new Blob instance from a value.
    # @param value [Blob, String, Array<Integer>] The value to convert.
    # @return [Blob] The created instance.
    def self.from(value)
      return value if value.is_a?(Blob)

      if value.is_a?(String)
        unless valid_hex?(value)
          raise StandardError, 'Cannot construct Blob from a non-hex string'
        end
        return Blob.new(hex_to_bytes(value))
      end

      if value.is_a?(::Array)
        return Blob.new(value)
      end

      raise StandardError, 'Cannot construct Blob from value given'
    end

    # Creates a Blob instance from a parser.
    # @param parser [BinaryParser] The parser to read from.
    # @param hint [Integer, nil] Optional width hint.
    # @return [Blob] The created instance.
    def self.from_parser(parser, hint = nil)
      new(parser.read(hint))
    end

  end


end
