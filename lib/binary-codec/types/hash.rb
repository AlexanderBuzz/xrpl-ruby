# frozen_string_literal: true

module BinaryCodec
  class Hash < ComparableSerializedType

    def initialize(bytes, width)
      @bytes = bytes
      @width = width
      if bytes.length != @width
        # raise StandardError, "Invalid Hash length #{bytes.length} for width #{@width}"
        raise StandardError, "Invalid Hash length #{bytes.length}"
      end
    end

    def self.from(hex_string)
      new(hex_to_bytes(hex_string))
    end

    def from_parser(parser, hint = nil)
      new(parser.read(hint || width))
    end

    def compare_to(other)
      @bytes <=> other.bytes
    end

    # Returns four bits at the specified depth within a hash
    #
    # @param depth [Integer] The depth of the four bits
    # @return [Integer] The number represented by the four bits
    def nibblet(depth)
      byte_index = depth > 0 ? (depth / 2).floor : 0
      b = bytes[byte_index]
      if depth.even?
        (b & 0xf0) >> 4
      else
        b & 0x0f
      end
    end

  end

  class Hash128 < Hash
    @width = 16
    @zero_128 = [0] * @width  # Array.new(@width, 0)

    class << self
      attr_reader :width, :zero_128
    end

    def initialize(bytes = nil)
      bytes = self.class.zero_128 if bytes&.empty?
      super(bytes, self.class.width)
    end

    def to_hex
      hex = bytes_to_hex(to_bytes)
      return '' if hex.match?(/^0+$/)
      hex
    end
  end

  class Hash160 < Hash
    @width = 20
    @zero_160 = [0] * @width  # Array.new(@width, 0)

    class << self
      attr_reader :width, :zero_160
    end

    def initialize(bytes = nil)
      bytes = self.class.zero_160 if bytes&.empty?
      super(bytes, self.class.width)
    end
  end

  class Hash192 < Hash
    @width = 24
    @zero_192 = [0] * @width  # Array.new(@width, 0)

    class << self
      attr_reader :width, :zero_192
    end

    def initialize(bytes = nil)
      bytes = self.class.zero_192 if bytes&.empty?
      super(bytes, self.class.width)
    end
  end

  class Hash256 < Hash
    @width = 32
    @zero_256 = [0] * @width  # Array.new(@width, 0)

    class << self
      attr_reader :width, :zero_256
    end

    def initialize(bytes = nil)
      bytes = self.class.zero_256 if bytes&.empty?
      super(bytes, self.class.width)
    end
  end

end
