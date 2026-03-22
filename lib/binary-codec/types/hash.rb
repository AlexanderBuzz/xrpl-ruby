# frozen_string_literal: true

module BinaryCodec
  class Hash < ComparableSerializedType
    # Returns the width of the Hash type in bytes.
    # @return [Integer] The width.
    def self.width
      @width
    end

    def initialize(bytes = nil)
      bytes = Array.new(self.class.width, 0) if bytes.nil? || bytes.empty?
      super(bytes)
      if @bytes.length != self.class.width
        raise StandardError, "Invalid Hash length #{@bytes.length}"
      end
    end

    # Creates a new Hash instance from a value.
    # @param value [Hash, String, Array<Integer>] The value to convert.
    # @return [Hash] The created instance.
    def self.from(value)
      return value if value.is_a?(self)

      if value.is_a?(String)
        return new if value.empty?
        return new(hex_to_bytes(value))
      end

      if value.is_a?(::Array)
        return new(value)
      end

      raise StandardError, "Cannot construct #{self} from the value given"
    end

    # Creates a Hash instance from a parser.
    # @param parser [BinaryParser] The parser to read from.
    # @param hint [Integer, nil] Optional width hint.
    # @return [Hash] The created instance.
    def self.from_parser(parser, hint = nil)
      new(parser.read(hint || width))
    end

    # Compares this Hash to another Hash.
    # @param other [Hash] The other Hash to compare to.
    # @return [Integer] Comparison result (-1, 0, or 1).
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

    def initialize(bytes = nil)
      super(bytes)
    end

    def to_hex
      hex = bytes_to_hex(to_bytes)
      return '' if hex.match?(/^0+$/)
      hex
    end
  end

  class Hash160 < Hash
    @width = 20

    def initialize(bytes = nil)
      super(bytes)
    end
  end

  class Hash192 < Hash
    @width = 24

    def initialize(bytes = nil)
      super(bytes)
    end
  end

  class Hash256 < Hash
    @width = 32

    def initialize(bytes = nil)
      super(bytes)
    end
  end

end
