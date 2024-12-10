require "xrpl-ruby"

base_x = Core::Base58XRP.new

encoded = base_x.encode("test")
puts "Encoded: #{encoded}"

decoded = base_x.decode(encoded)
puts "Decoded: #{decoded}"