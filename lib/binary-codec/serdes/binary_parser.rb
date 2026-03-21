# frozen_string_literal: true

module BinaryCodec

  class BinaryParser

    attr_reader :definitions

    def initialize(hex_bytes = '')
      @bytes = hex_to_bytes(hex_bytes)
      @definitions = Definitions.instance
    end

    # Returns the first byte in the stream without consuming it.
    # @return [Integer] The first byte.
    def peek
      if @bytes.empty?
        raise StandardError.new
      end
      @bytes[0]
    end

    # Consumes n bytes from the stream.
    # @param n [Integer] The number of bytes to skip.
    def skip(n)
      if n > @bytes.length
        raise StandardError.new
      end
      @bytes = @bytes[n..-1]
    end

    # Reads n bytes from the stream.
    # @param n [Integer] The number of bytes to read.
    # @return [Array<Integer>] The read bytes.
    def read(n)
      if n > @bytes.length
        raise StandardError.new('End of byte stream reached')
      end

      slice = @bytes[0, n]
      skip(n)
      slice
    end

    # Reads n bytes and converts them to an unsigned integer.
    # @param n [Integer] The number of bytes to read (1-4).
    # @return [Integer] The resulting integer.
    def read_uint_n(n)
      if n <= 0 || n > 4
        raise StandardError.new('invalid n')
      end
      read(n).reduce(0) { |a, b| (a << 8) | b }
    end

    # Reads a 1-byte unsigned integer.
    # @return [Integer] The 8-bit integer.
    def read_uint8
      read_uint_n(1)
    end

    # Reads a 2-byte unsigned integer.
    # @return [Integer] The 16-bit integer.
    def read_uint16
      read_uint_n(2)
    end

    # Reads a 4-byte unsigned integer.
    # @return [Integer] The 32-bit integer.
    def read_uint32
      read_uint_n(4)
    end

    # Returns the number of bytes remaining in the stream.
    # @return [Integer] The remaining size.
    def size
      @bytes.length
    end

    # Checks if the end of the stream has been reached.
    # @param custom_end [Integer, nil] Optional offset to check against.
    # @return [Boolean] True if at the end, false otherwise.
    def end?(custom_end = nil)
      length = @bytes.length
      length == 0 || (!custom_end.nil? && length <= custom_end)
    end

    # Reads variable length data from the stream.
    # @return [Array<Integer>] The read bytes.
    def read_variable_length
      read(read_variable_length_length)
    end

    # Reads the length of a variable length data segment.
    # @return [Integer] The length.
    def read_variable_length_length
      b1 = read_uint8
      if b1 <= 192
        b1
      elsif b1 <= 240
        b2 = read_uint8
        193 + (b1 - 193) * 256 + b2
      elsif b1 <= 254
        b2 = read_uint8
        b3 = read_uint8
        12481 + (b1 - 241) * 65536 + b2 * 256 + b3
      else
        raise StandardError.new('Invalid variable length indicator')
      end
    end

    # Reads a field header from the stream.
    # @return [FieldHeader] The field header.
    def read_field_header
      type = read_uint8
      nth = type & 15
      type >>= 4

      if type == 0
        type = read_uint8
        if type == 0 || type < 16
          raise StandardError.new("Cannot read FieldOrdinal, type_code #{type} out of range")
        end
      end

      if nth == 0
        nth = read_uint8
        if nth == 0 || nth < 16
          raise StandardError.new("Cannot read FieldOrdinal, field_code #{nth} out of range")
        end
      end

      FieldHeader.new(type: type, nth: nth) # (type << 16) | nth for read_field_ordinal
    end

    # Reads a field instance from the stream.
    # @return [FieldInstance] The field instance.
    def read_field
      field_header = read_field_header
      field_name = @definitions.get_field_name_from_header(field_header)

      @definitions.get_field_instance(field_name)
    end

    # Reads a value of the specified type from the stream.
    # @param type [Class] The class of the type to read (subclass of SerializedType).
    # @return [SerializedType] The read value.
    def read_type(type)
      type.from_parser(self)
    end

    # Returns the associated type for a given field.
    # @param field [FieldInstance] The field instance.
    # @return [Class] The associated SerializedType subclass.
    def type_for_field(field)
      field.associated_type
    end

    # Reads the value of a specific field from the stream.
    # @param field [FieldInstance] The field to read.
    # @return [SerializedType] The read value.
    def read_field_value(field)
      type = SerializedType.get_type_by_name(field.type)

      if type.nil?
        raise StandardError.new("unsupported: (#{field.name}, #{field.type.name})")
      end

      size_hint = field.is_variable_length_encoded ? read_variable_length_length : nil
      value = type.from_parser(self, size_hint)

      if value.nil?
        raise StandardError.new("from_parser for (#{field.name}, #{field.type.name}) -> nil")
      end

      value
    end

    # get_size
    # read_field_and_value

  end

end
