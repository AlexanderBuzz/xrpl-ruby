# @!attribute
require_relative 'base_x'
require_relative 'base_58_xrp'

def bytes_to_hex(bytes)
  bytes.pack('C*').unpack1('H*').upcase
end

def hex_to_bytes(hex)
  [hex].pack('H*').bytes
end

def hex_to_bin(hex)
  [hex].pack("H*")
end

def bin_to_hex(bin)
  bin.unpack("H*").first.upcase
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

#def equal?(bytes1, bytes2)
#  return false unless bytes1.length == bytes2.length
#
#  bytes1.each_with_index do |byte, index|
#    return false unless byte == bytes2[index]
#  end
#
#  true
#end