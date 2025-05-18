# frozen_string_literal: true
#
require 'digest'
require_relative "../core/core"

module AddressCodec
  class Codec

    def initialize
      @codec = Core::Base58XRP.new
    end

    def encode(bytes, opts)
      versions = opts[:versions]
      encode_versioned(bytes, versions, opts[:expected_length])
    end

    def decode(base58string, opts)
      versions = opts[:versions]
      types = opts[:version_types]

      without_sum = decode_checked(base58string)

      if versions.length > 1 && !opts[:expected_length]
        raise 'expected_length is required because there are >= 2 possible versions'
      end

      version_length_guess = versions[0].is_a?(Numeric) ? 1 : versions[0].length
      payload_length = opts[:expected_length] || without_sum.length - version_length_guess
      version_bytes = without_sum[0...-payload_length]
      payload = without_sum[-payload_length..-1]

      versions.each_with_index do |version, i|
        version = Array(version)
        if version_bytes == version
          return {
            version: version,
            bytes: payload,
            type: types ? types[i] : nil
          }
        end
      end

      raise 'version_invalid: version bytes do not match any of the provided version(s)'
    end

    def encode_checked(bytes)
      check = sha256(sha256(bytes))[0, 4]
      encode_raw(bytes + check)
    end

    def decode_checked(base58string)
      bytes = decode_raw(base58string)

      if bytes.length < 5
        raise 'invalid_input_size: decoded data must have length >= 5'
      end

      unless verify_check_sum(bytes)
        raise 'checksum_invalid'
      end

      bytes[0...-4]
    end

    private

    def encode_versioned(bytes, versions, expected_length)
      unless check_byte_length(bytes, expected_length)
        raise 'unexpected_payload_length: bytes.length does not match expected_length. Ensure that the bytes are a Uint8Array.'
      end

      encode_checked(concat_args(versions, bytes))
    end

    def encode_raw(bytes)
      @codec.encode(bytes.pack('C*'))
    end

    def decode_raw(base58string)
      @codec.decode(base58string).unpack('C*')
    end

    def sha256(bytes)
      binary_value = bytes.pack('C*')
      binary_hash = Digest::SHA256.digest(binary_value)
      binary_hash.unpack('C*')
    end

    def verify_check_sum(bytes)
      computed = sha256(sha256(bytes[0...-4]))[0, 4]
      checksum = bytes[-4, 4]
      computed == checksum
    end

  end

end