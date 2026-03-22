# frozen_string_literal: true

module BinaryCodec
  class BytesList

    attr_reader :bytes_array

    def initialize
      @bytes_array = []
    end

    # Returns the total length of all bytes in the list.
    # @return [Integer] The total length.
    def get_length
      @bytes_array.inject(0) { |sum, arr| sum + arr.length }
    end

    # Adds bytes to the list.
    # @param bytes_arg [Array<Integer>, Integer] The bytes to add.
    # @return [BytesList] self for chaining.
    def put(bytes_arg)
      bytes = bytes_arg.is_a?(Integer) ? [bytes_arg] : bytes_arg.dup
      @bytes_array << bytes
      self # Allow chaining
    end

    # Puts the bytes into another byte sink.
    # @param list [Object] The sink to put bytes into.
    def to_byte_sink(list)
      list.put(to_bytes)
    end

    # Returns all bytes as a single flat array.
    # @return [Array<Integer>] The flattened byte array.
    def to_bytes
      @bytes_array.flatten # TODO: Uses concat in xrpl.js, maybe implement that instead
    end

    # Returns the hex representation of all bytes in the list.
    # @return [String] The hex string.
    def to_hex
      bytes_to_hex(to_bytes)
    end

  end

end
