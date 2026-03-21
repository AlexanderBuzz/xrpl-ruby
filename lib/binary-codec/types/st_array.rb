# frozen_string_literal: true

module BinaryCodec
  class STArray < SerializedType
    def initialize(byte_buf = nil)
      super(byte_buf || [])
    end

    def self.from(value, definitions = nil)
      return value if value.is_a?(STArray)
      definitions ||= Definitions.instance

      if value.is_a?(String)
        return STArray.new(hex_to_bytes(value))
      end

      if value.is_a?(Array)
        bytes = []
        value.each do |item|
          obj = STObject.from(item, nil, definitions)
          bytes.concat(obj.to_bytes)
          bytes.concat([0xF1]) # ArrayItemEndMarker
        end
        bytes.concat([0xF1]) # ArrayEndMarker
        return STArray.new(bytes)
      end

      raise StandardError, "Cannot construct STArray from #{value.class}"
    end

    def self.from_parser(parser, _hint = nil)
      bytes = []
      until parser.end?(1) # Look ahead for end marker
        obj = STObject.from_parser(parser)
        bytes.concat(obj.to_bytes)
        bytes.concat(parser.read(1)) # Should be 0xF1 (ArrayItemEndMarker)
      end
      parser.read(1) # Consume 0xF1 (ArrayEndMarker)
      STArray.new(bytes)
    end

    def to_json(_definitions = nil, _field_name = nil)
      parser = BinaryParser.new(to_hex)
      result = []
      until parser.end?
        obj = STObject.from_parser(parser)
        result << JSON.parse(obj.to_json)
        # In xrpl.js, array items are STObjects. 
        # After each STObject, there might be an ArrayItemEndMarker if we're not at the end.
        # But wait, STObject.from_parser already reads until ObjectEndMarker.
        # STArray in XRPL is a list of objects, each ending with ObjectEndMarker.
        # The whole array ends with ArrayEndMarker (0xF1).
        # Actually, standard XRPL STArray: [FieldHeader][STObject][FieldHeader][STObject]...[0xF1]
        # Wait, I need to check how xrpl.js handles STArray.
      end
      result
    end
  end
end
