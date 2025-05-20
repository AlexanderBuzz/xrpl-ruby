module BinaryCodec
  class STObject  < SerializedType

    OBJECT_END_MARKER_BYTE = [225]
    OBJECT_END_MARKER = 'ObjectEndMarker'.freeze
    ST_OBJECT = 'STObject'.freeze
    DESTINATION = 'Destination'.freeze
    ACCOUNT = 'Account'.freeze
    SOURCE_TAG = 'SourceTag'.freeze
    DEST_TAG = 'DestinationTag'.freeze

    # attr_reader :type, :bytes
    #
    def initialize(byte_buf = nil)
      @bytes = byte_buf || Array.new(0)
    end

    # Construct a STObject from a BinaryParser
    #
    # @param parser [BinaryParser] BinaryParser to read STObject from
    # @param size_hint [Integer] Optional size hint for the object
    # @return [STObject] A STObject object
    def self.from_parser(parser, size_hint = nil)
      list = BytesList.new
      bytes = BinarySerializer.new(list)

      until parser.end?
        field = parser.read_field

        break if field.name == OBJECT_END_MARKER

        associated_value = parser.read_field_value(field)

        bytes.write_field_and_value(field, associated_value)
        bytes.put(OBJECT_END_MARKER_BYTE) if field.type == ST_OBJECT
      end

      STObject.new(list.to_bytes)
    end

    # Method to get the JSON interpretation of self.bytes
    #
    # @return [String] A stringified JSON object
    def to_json()
      parser = BinaryParser.new(to_s)
      accumulator = {}

      until parser.end?
        field = parser.read_field
        break if field.name == OBJECT_END_MARKER # Break if the object end marker is reached
        value = parser.read_field_value(field).to_json
        value = JSON.parse(value) if field.type == ST_OBJECT || field.type == Amount
        accumulator[field.name] = value
      end

      JSON.generate(accumulator)
    end

  end
end