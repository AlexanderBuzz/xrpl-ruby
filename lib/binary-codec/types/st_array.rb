# frozen_string_literal: true

module BinaryCodec
  class STArray < SerializedType
    def initialize(byte_buf = nil)
      super(byte_buf || [])
    end

    # Creates a new STArray instance from a value.
    # @param value [STArray, String, Array<Hash>] The value to convert.
    # @param definitions [Definitions, nil] Optional definitions.
    # @return [STArray] The created instance.
    def self.from(value, definitions = nil)
      return value if value.is_a?(STArray)
      definitions ||= Definitions.instance

      if value.is_a?(String)
        return STArray.new(hex_to_bytes(value))
      end

      if value.is_a?(Array)
        bytes = []
        value.each do |item|
          # item should be a hash with one key (the field name)
          # e.g., {"Signer" => { ... }}
          if item.is_a?(::Hash)
            # Use keys.first and unwrap directly
            field_name = item.keys.first.to_s
            field_value = item[item.keys.first]
            
            field = definitions.get_field_instance(field_name)
            bytes.concat(field.header.to_bytes)
            
            obj = STObject.from(field_value, nil, definitions)
            bytes.concat(obj.to_bytes)
            bytes.concat([0xE1]) unless bytes.last == 0xE1
          else
            raise StandardError, "STArray item must be a Hash, got #{item.class}"
          end
        end
        bytes.concat([0xF1]) # ArrayEndMarker
        return STArray.new(bytes)
      end

      raise StandardError, "Cannot construct STArray from #{value.class}"
    end

    # Creates an STArray instance from a parser.
    # @param parser [BinaryParser] The parser to read from.
    # @param _hint [Integer, nil] Unused.
    # @return [STArray] The created instance.
    def self.from_parser(parser, _hint = nil)
      bytes = []
      until parser.end?
        # Check if we reached the ArrayEndMarker (0xF1)
        if parser.peek == 0xF1
          parser.read(1) # Consume 0xF1
          break
        end

        # In STArray, each item is an STObject with its field header.
        # So we read the field header first.
        field_header = parser.read_field_header
        
        # Then we read the STObject
        obj = STObject.from_parser(parser)
        
        # Reconstruct the serialized item: [FieldHeader][STObject][ObjectEndMarker]
        bytes.concat(field_header.to_bytes)
        bytes.concat(obj.to_bytes)
        bytes.concat([0xE1]) unless bytes.last == 0xE1
      end
      STArray.new(bytes)
    end

    # Returns the JSON representation of the STArray.
    # @param definitions [Definitions, nil] Definitions for lookup.
    # @param _field_name [String, nil] Unused.
    # @return [Array<Hash>] The JSON representation.
    def to_json(definitions = nil, _field_name = nil)
      definitions ||= Definitions.instance
      parser = BinaryParser.new(to_hex)
      result = []
      until parser.end?
        begin
          # Check if we reached the ArrayEndMarker (0xF1) or if peek fails
          break if parser.peek == 0xF1
          
          # Read field header of the array item (e.g., "Signer")
          field_header = parser.read_field_header
          field_name = definitions.get_field_name_from_header(field_header)
          
          # Read the STObject item
          obj = STObject.from_parser(parser)
          
          # Array item in JSON is { "FieldName": { ... } }
          item_json = obj.to_json(definitions)
          result << { field_name => item_json.is_a?(String) ? JSON.parse(item_json) : item_json }
        rescue => e
          break
        end
      end
      result
    end
  end
end
