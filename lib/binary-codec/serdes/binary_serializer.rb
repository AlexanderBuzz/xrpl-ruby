# frozen_string_literal: true

module BinaryCodec
  class BinarySerializer

    def initialize(sink)
      @sink = sink || BytesList.new
    end

    def write(value)
      value.to_byte_sink(@sink)
    end

    def put(bytes)
      @sink.put(bytes)
    end

    def write_type(type, value)
      write(type.from(value))
    end

    def write_bytes_list(bytes_list)
      bytes_list.to_byte_sink(@sink)
    end

    def write_field_and_value(field, value, is_unl_modify_workaround = false)
      field_header = FieldHeader.new(type: field.header.type, nth: field.nth)
      type_class = SerializedType.get_type_by_name(field.type)
      associated_value = type_class.from(value)

      if !associated_value.respond_to?(:to_byte_sink) || field.name.nil?
        raise 'Error'
      end

      @sink.put(field_header.to_bytes)

      if field.is_variable_length_encoded
        write_length_encoded(associated_value, is_unl_modify_workaround)
      else
        associated_value.to_byte_sink(@sink)
      end
    end

    def write_length_encoded(value, is_unl_modify_workaround = false)
      bytes = BytesList.new

      unless is_unl_modify_workaround
        # This part doesn't happen for the Account field in a UNLModify transaction
        value.to_byte_sink(bytes)
      end

      self.put(encode_variable_length(bytes.get_length))
      write_bytes_list(bytes)
    end

    private

    def encode_variable_length(length)
      len_bytes = [0, 0, 0] # Create an array to hold 3 bytes (default 0)

      if length <= 192
        len_bytes[0] = length
        return len_bytes[0, 1] # Equivalent to slice(0, 1)
      elsif length <= 12480
        length -= 193
        len_bytes[0] = 193 + (length >> 8) # Equivalent to length >>> 8 in TypeScript
        len_bytes[1] = length & 0xff
        return len_bytes[0, 2] # Equivalent to slice(0, 2)
      elsif length <= 918744
        length -= 12481
        len_bytes[0] = 241 + (length >> 16)
        len_bytes[1] = (length >> 8) & 0xff
        len_bytes[2] = length & 0xff
        return len_bytes[0, 3] # Equivalent to slice(0, 3)
      end

      raise 'Overflow error'
    end

  end

end
