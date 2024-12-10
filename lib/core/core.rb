# @!attribute
require_relative 'base_x'
require_relative 'base_58_xrp'

def bytes_to_hex(bytes)
  bytes.pack('C*').unpack1('H*')
end

def hex_to_bytes(hex)
  [hex].pack('H*').bytes
end

def hex_to_bin(hex)
  [hex].pack("H*")
end

def bin_to_hex(bin)
  bin.unpack("H*").first
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
    is_scalar(arg) ? [arg] : arg.to_a
  end
end

def is_scalar(val)
  val.is_a?(Numeric)
end