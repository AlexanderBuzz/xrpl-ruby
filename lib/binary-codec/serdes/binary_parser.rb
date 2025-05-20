# frozen_string_literal: true

module BinaryCodec

  class BinaryParser

    attr_reader :definitions

    def initialize(hex_bytes = '')
      @bytes = hex_to_bytes(hex_bytes)
      @definitions = Definitions.instance
    end

    def peek
      if @bytes.empty?
        raise StandardError.new
      end
      @bytes[0]
    end

    def skip(n)
      if n > @bytes.length
        raise StandardError.new
      end
      @bytes = @bytes[n..-1]
    end

    def read(n)
      if n > @bytes.length
        raise StandardError.new('End of byte stream reached')
      end

      slice = @bytes[0, n]
      skip(n)
      slice
    end

    def read_uint_n(n)
      if n <= 0 || n > 4
        raise StandardError.new('invalid n')
      end
      read(n).reduce(0) { |a, b| (a << 8) | b }
    end

    def read_uint8
      read_uint_n(1)
    end

    def read_uint16
      read_uint_n(2)
    end

    def read_uint32
      read_uint_n(4)
    end

    def size
      @bytes.length
    end

    def end?(custom_end = nil)
      length = @bytes.length
      length == 0 || (!custom_end.nil? && length <= custom_end)
    end

    def read_variable_length
      read(read_variable_length_length)
    end

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

    def read_field
      field_header = read_field_header
      field_name = @definitions.get_field_name_from_header(field_header)

      @definitions.get_field_instance(field_name)
    end

    def read_type(type)
      type.from_parser(self)
    end

    def type_for_field(field)
      field.associated_type
    end

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
