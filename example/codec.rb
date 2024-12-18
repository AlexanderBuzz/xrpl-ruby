require "xrpl-ruby"

address_codec = AddressCodec::AddressCodec.new

# input = "test"
# puts "Input String: #{test}"
# encoded = codec.encode_raw(test.bytes)
# puts "Encoded: #{encoded}"
# decoded = codec.decode_raw(encoded)
# puts "Decoded: #{decoded}"

# encoded = codec.encode_seed(hex_to_bytes("4C3A1D213FBDFB14C7C28D609469B341"))
# puts "Encoded: #{encoded}"

classic_address = "r9cZA1mLK5R5Am25ArfXFmqgNwjZgnfk59"
puts "Classic Address: #{classic_address}"
x_address = address_codec.classic_address_to_x_address(classic_address, 0, false)
puts "xAddress: #{x_address}"