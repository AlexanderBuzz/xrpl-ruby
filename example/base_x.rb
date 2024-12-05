require "xrpl-ruby"

alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
base_x = Core::BaseX.new(alphabet)

encoded = base_x.encode("test")
puts "Encoded: #{encoded}"

decoded = base_x.decode(encoded)
puts "Decoded: #{decoded}"