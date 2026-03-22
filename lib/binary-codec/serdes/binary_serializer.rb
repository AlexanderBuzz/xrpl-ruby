# frozen_string_literal: true

module BinaryCodec
  class BinarySerializer

    def initialize(sink)
      @sink = sink || BytesList.new
    end

    # Serializes a value into the sink.
    # @param value [SerializedType] The value to write.
    def write(value)
      value.to_byte_sink(@sink)
    end

    # Adds raw bytes to the sink.
    # @param bytes [Array<Integer>] The bytes to add.
    def put(bytes)
      @sink.put(bytes)
    end

    # Serializes a value of a given type.
    # @param type [Class] The class of the type (subclass of SerializedType).
    # @param value [Object] The value to serialize.
    def write_type(type, value)
      write(type.from(value))
    end

    # Writes a BytesList into the sink.
    # @param bytes_list [BytesList] The bytes list to write.
    def write_bytes_list(bytes_list)
      bytes_list.to_byte_sink(@sink)
    end

    # Writes a field and its value into the sink.
    # @param field [FieldInstance] The field to write.
    # @param value [Object] The value of the field.
    # @param is_unl_modify_workaround [Boolean] Whether to apply the UNLModify workaround.
    def write_field_and_value(field, value, is_unl_modify_workaround = false)
      # Special case for Blob fields that are empty (e.g., SigningPubKey = "")
      # In Ruby, Blob.from("") returns an empty Blob.
      # If we want to force 0x00 length prefix, we handle it here.
      if field.type == 'Blob' && (value == "" || (value.is_a?(Array) && value.empty?))
        @sink.put(field.header.to_bytes)
        @sink.put([0]) # length 0
        return
      end

      field_header = field.header
      associated_value = field.associated_type.from(value)

      @sink.put(field_header.to_bytes)

      if field.is_variable_length_encoded
        write_length_encoded(associated_value, is_unl_modify_workaround)
      else
        associated_value.to_byte_sink(@sink)
        if field.type == 'STObject'
          @sink.put([0xE1]) # ObjectEndMarker
        end
      end
    end

    # Writes a value with its length encoded prefix.
    # @param value [SerializedType] The value to write.
    # @param is_unl_modify_workaround [Boolean] Whether to apply the UNLModify workaround.
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
