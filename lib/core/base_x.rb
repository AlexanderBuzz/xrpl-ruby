# frozen_string_literal: true

module Core

  class BaseX
    # Initializes a new BaseX instance with the given alphabet.
    # @param alphabet [String] The alphabet to use for encoding and decoding.
    def initialize(alphabet)
      @alphabet = alphabet
      @base = alphabet.length
      @alphabet_map = {}
      alphabet.chars.each_with_index { |char, index| @alphabet_map[char] = index }
    end

    # Encodes a byte array into a string using the alphabet.
    # @param buffer [String] The byte string to encode.
    # @return [String] The encoded string.
    def encode(buffer)
      return @alphabet[0] if buffer.empty?

      digits = [0]
      buffer.each_byte do |byte|
        carry = byte
        digits.each_with_index do |digit, i|
          carry += digit << 8
          digits[i] = (carry % @base).to_i
          carry = (carry / @base).abs.to_i
        end

        while carry > 0 do
          digits << (carry % @base).to_i
          carry = (carry / @base).abs.to_i
        end
      end

      buffer.each_byte.take_while { |byte| byte == 0 }.each { digits << 0 }
      digits.reverse.map { |digit| @alphabet[digit] }.join
    end

    # Decodes a string into a byte string using the alphabet.
    # @param string [String] The string to decode.
    # @return [String] The decoded byte string.
    def decode(string)
      return '' if string.empty?

      bytes = [0]
      string.each_char do |char|
        raise ArgumentError, "Invalid character found: #{char}" unless @alphabet_map.key?(char)

        carry = @alphabet_map[char]
        bytes.each_with_index do |byte, i|
          carry += byte * @base
          bytes[i] = carry & 0xff
          carry >>= 8
        end

        while carry > 0 do
          bytes << (carry & 0xff)
          carry >>= 8
        end
      end

      string.chars.take_while { |char| char == @alphabet[0] }.each { bytes << 0 }
      bytes.reverse.pack('C*')
    end

  end

end