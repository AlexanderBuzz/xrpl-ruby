# frozen_string_literal: true

require 'securerandom'

# Returns a random byte array of the given size.
# @param size [Integer] The number of bytes to generate.
# @return [Array<Integer>] The generated random byte array.
def random_bytes(size)
  SecureRandom.random_bytes(size).bytes
end

# Converts a byte array to a hex string.
# @param bytes [Array<Integer>] The byte array to convert.
# @return [String] The hex string.
def bytes_to_hex(bytes)
  bytes.pack('C*').unpack1('H*').upcase
end
# Converts a hex string to a byte array.
# @param hex [String] The hex string to convert.
# @return [Array<Integer>] The byte array.
def hex_to_bytes(hex)
  raise ArgumentError, 'Invalid hex string' unless valid_hex?(hex)
  [hex].pack('H*').bytes
end

# Converts a binary string to a hex string.
# @param bin [String] The binary string to convert.
# @return [String] The hex string.
def bin_to_hex(bin)
  bin.unpack("H*").first.upcase
end

# Converts a hex string to a binary string.
# @param hex [String] The hex string to convert.
# @return [String] The binary string.
def hex_to_bin(hex)
  raise ArgumentError, 'Invalid hex string' unless valid_hex?(hex)
  [hex].pack("H*")
end

# Converts a hex string to a string with the given encoding.
# @param hex [String] The hex string to convert.
# @param encoding [String] The encoding to use.
# @return [String] The decoded string.
def hex_to_string(hex, encoding = 'utf-8')
  raise ArgumentError, 'Invalid hex string' unless valid_hex?(hex)
  hex_to_bin(hex).force_encoding(encoding).encode('utf-8')
end

# Converts a string to a hex string.
# @param string [String] The string to convert.
# @return [String] The hex string.
def string_to_hex(string)
  string.unpack1('H*').upcase
end

# Checks if a string is a valid hex string.
# @param str [String] The string to check.
# @return [Boolean] True if the string is a valid hex string, false otherwise.
def valid_hex?(str)
  str =~ /\A[0-9a-fA-F]*\z/ && str.length.even?
end

# Checks if a byte array has the expected length.
# @param bytes [Array<Integer>, String] The byte array or string to check.
# @param expected_length [Integer] The expected length.
# @return [Boolean] True if the length matches, false otherwise.
def check_byte_length(bytes, expected_length)
  if bytes.respond_to?(:byte_length)
    bytes.byte_length == expected_length
  else
    bytes.length == expected_length
  end
end

# Concatenates multiple arguments into a single array.
# @param args [Array] The arguments to concatenate.
# @return [Array] The concatenated array.
def concat_args(*args)
  args.flat_map do |arg|
    is_scalar?(arg) ? [arg] : arg.to_a
  end
end

# Checks if a value is a scalar.
# @param val [Object] The value to check.
# @return [Boolean] True if the value is a numeric scalar, false otherwise.
def is_scalar?(val)
  val.is_a?(Numeric)
end

# Converts an integer to a byte array.
# @param number [Integer] The integer to convert.
# @param width [Integer] The number of bytes in the result.
# @param byteorder [Symbol] The byte order (:big or :little).
# @return [Array<Integer>] The byte array.
def int_to_bytes(number, width = 1, byteorder = :big)
  bytes = []
  while number > 0
    bytes << (number & 0xFF)
    number >>= 8
  end

  while bytes.size < width
    bytes << 0
  end

  bytes.reverse! if byteorder == :big
  bytes
end