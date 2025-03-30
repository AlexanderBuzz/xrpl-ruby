# frozen_string_literal: true

module BinaryCodec
  class BytesList

    attr_reader :bytes_array

    def initialize
      @bytes_array = []
    end

    def get_length
      @bytes_array.inject(0) { |sum, arr| sum + arr.length }
    end

    def put(bytes_arg)
      bytes = bytes_arg.dup
      @bytes_array << bytes
      self # Allow chaining
    end

    def to_byte_sink(list)
      list.put(to_bytes)
    end

    def to_bytes
      @bytes_array.flatten # TODO: Uses concat in xrpl.js, maybe implement that instead
    end

    def to_hex
      bytes_to_hex(to_bytes)
    end

  end

end
