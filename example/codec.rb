require "xrpl-ruby"

codec = AddressCodec::XrpCodec.new

# encoded = codec.encode_raw("test".bytes)
# puts "Encoded: #{encoded}"

# decoded = codec.decode_raw(encoded)
# puts "Decoded: #{decoded}"

encoded = codec.encode_seed(["4C3A1D213FBDFB14C7C28D609469B341"].pack('H*').bytes)
puts "Encoded: #{encoded}"