# frozen_string_literal: true

require_relative '../../core/core'

module BinaryCodec
  class Currency < Hash160

    XRP_HEX_REGEX = /^0{40}$/
    ISO_REGEX = /^[A-Z0-9a-z?!@#$%^&*(){}\[\]\|]{3}$/
    HEX_REGEX = /^[A-F0-9]{40}$/
    STANDARD_FORMAT_HEX_REGEX = /^0{24}[\x00-\x7F]{6}0{10}$/

    attr_reader :iso

    @width = 20

    def initialize(byte_buf = nil)
      super(byte_buf || Array.new(20, 0)) # Defaults to XRP bytes if no buffer is given
      hex = bytes_to_hex(@bytes)

      if XRP_HEX_REGEX.match?(hex)
        @_iso = 'XRP'
      elsif STANDARD_FORMAT_HEX_REGEX.match?(hex)
        @_iso = iso_code_from_hex(@bytes[12..14])
      else
        @_iso = nil
      end
    end

    def iso
      @_iso
    end

    def self.from(value)
      return value if value.is_a?(Currency)

      if value.is_a?(String)
        return Currency.new(bytes_from_representation(value))
      end

      raise StandardError, 'Cannot construct Currency from value given'
    end

    def to_json
      iso = self.iso
      return iso unless iso.nil?

      bytes_to_hex(@bytes)
    end

    private

    def iso_code_from_hex(code)
      iso = hex_to_string(bytes_to_hex(code))
      return nil if iso == 'XRP'
      return iso if is_iso_code(iso)

      nil
    end

    def is_iso_code(iso)
      !!(ISO_REGEX.match(iso)) # Equivalent to test for regex
    end

    def self.bytes_from_representation(input)
      unless is_valid_representation(input)
        raise StandardError, "Unsupported Currency representation: #{input}"
      end

      input.length == 3 ? self.iso_to_bytes(input) : hex_to_bytes(input)
    end

    def self.iso_to_bytes(iso)
      bytes = Array.new(20, 0) # Equivalent to Uint8Array(20)
      if iso != 'XRP'
        iso_bytes = iso.chars.map(&:ord)
        # Insert iso_bytes at index 12
        bytes[12, iso_bytes.length] = iso_bytes
      end
      bytes
    end

    def self.is_valid_representation(input)
      if input.is_a?(Array)
        self.is_bytes_array(input)
      else
        self.is_string_representation(input)
      end
    end

    def self.is_string_representation(input)
      input.length == 3 || is_hex(input)
    end

    def self.is_bytes_array(bytes)
      bytes.length == 20
    end

    def self.is_hex(hex)
      !!(HEX_REGEX.match(hex)) # Special case for Vurrency type, do not conflate with valid_hex? function
    end

  end

end
