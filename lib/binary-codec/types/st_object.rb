# frozen_string_literal: true

module BinaryCodec
  class STObject < SerializedType

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

    def self.from(value, filter = nil, definitions = nil)
      return value if value.is_a?(STObject)
      definitions ||= Definitions.instance

      if value.is_a?(String)
        return STObject.new(hex_to_bytes(value))
      end

      if value.is_a?(Array)
        return STObject.new(value)
      end

      list = BytesList.new
      serializer = BinarySerializer.new(list)
      is_unl_modify = false

      # Handle X-Addresses and check for duplicate tags
      processed_value = value.each_with_object({}) do |(key, val), acc|
        if val && val.is_a?(String) && AddressCodec::AddressCodec.new.valid_x_address?(val)
          handled = handle_x_address(key.to_s, val)
          check_for_duplicate_tags(handled, value)
          acc.merge!(handled)
        else
          acc[key.to_s] = val
        end
      end

      sorted_fields = processed_value.keys.map do |field_name|
        field = definitions.get_field_instance(field_name)
        raise "Field #{field_name} is not defined" if field.nil?
        field
      end.select(&:is_serialized).sort_by(&:ordinal)

      sorted_fields = sorted_fields.select(&filter) if filter

      sorted_fields.each do |field|
        associated_value = processed_value[field.name]
        next if associated_value.nil?

        # Special handling for UNLModify
        if field.name == 'UNLModify' # This might need more specific check depending on value
           is_unl_modify = true
        end
        is_unl_modify_workaround = (field.name == 'Account' && is_unl_modify)

        serializer.write_field_and_value(field, associated_value, is_unl_modify_workaround)

        if field.type == 'STObject'
          serializer.put(OBJECT_END_MARKER_BYTE)
        end
      end

      STObject.new(list.to_bytes)
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
    def to_json(_definitions = nil, _field_name = nil)
      parser = BinaryParser.new(to_hex)
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

    private

    # Break down an X-Address into an account and a tag
    #
    # @param field [String] Name of the field
    # @param x_address [String] X-Address corresponding to the field
    # @return [Hash] A hash with the classic address and tag (if present)
    def handle_x_address(field, x_address)
      address_codec = AddressCodec::AddressCodec.new
      decoded = address_codec.x_address_to_classic_address(x_address)

      tag_name = if field == 'Destination'
                   'DestinationTag'
                 elsif field == 'Account'
                   'SourceTag'
                 elsif decoded[:tag]
                   raise "#{field} cannot have an associated tag"
                 end

      decoded[:tag] ? { field => decoded[:classic_address], tag_name => decoded[:tag] } : { field => decoded[:classic_address] }
    end

    def self.check_for_duplicate_tags(obj1, obj2)
      if obj1['SourceTag'] && obj2['SourceTag']
        raise 'Cannot have Account X-Address and SourceTag'
      end

      if obj1['DestinationTag'] && obj2['DestinationTag']
        raise 'Cannot have Destination X-Address and DestinationTag'
      end
    end


  end
end