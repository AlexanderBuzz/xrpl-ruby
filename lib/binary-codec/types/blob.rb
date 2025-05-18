# frozen_string_literal: true

require_relative '../../core/core'

module BinaryCodec
  class Blob < SerializedType

    def initialize(byte_buf = nil)
      @bytes = byte_buf || Array.new(0)
    end

    def self.from(value)
      return value if value.is_a?(Blob)

      if value.is_a?(String)
        if value !~ /^[A-F0-9]*$/i
          raise StandardError, 'Cannot construct Blob from a non-hex string'
        end
        return Blob.new(hex_to_bytes(value))
      end

      raise StandardError, 'Cannot construct Blob from value given'
    end

    def self.from_parser(parser, hint = nil)
      Blob.new(parser.read(hint))
    end

  end


end
