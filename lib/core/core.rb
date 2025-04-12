# @!attribute
require_relative 'base_x'
require_relative 'base_58_xrp'
require 'securerandom'

def random_bytes(size)
  SecureRandom.random_bytes(size).bytes
end

def bytes_to_hex(bytes)
  bytes.pack('C*').unpack1('H*').upcase
end
def hex_to_bytes(hex)
  raise ArgumentError, 'Invalid hex string' unless valid_hex?(hex)
  [hex].pack('H*').bytes
end

def bin_to_hex(bin)
  bin.unpack("H*").first.upcase
end

def hex_to_bin(hex)
  raise ArgumentError, 'Invalid hex string' unless valid_hex?(hex)
  [hex].pack("H*")
end

def hex_to_string(hex, encoding = 'utf-8')
  raise ArgumentError, 'Invalid hex string' unless valid_hex?(hex)
  hex_to_bin(hex).force_encoding(encoding).encode('utf-8')
end

def string_to_hex(string)
  string.unpack1('H*').upcase
end

def valid_hex?(str)
  str =~ /\A[0-9a-fA-F]*\z/ && str.length.even?
end

def check_byte_length(bytes, expected_length)
  if bytes.respond_to?(:byte_length)
    bytes.byte_length == expected_length
  else
    bytes.length == expected_length
  end
end

def concat_args(*args)
  args.flat_map do |arg|
    is_scalar?(arg) ? [arg] : arg.to_a
  end
end

def is_scalar?(val)
  val.is_a?(Numeric)
end