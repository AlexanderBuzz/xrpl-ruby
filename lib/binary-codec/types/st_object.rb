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

    # Creates a new STObject instance from a value.
    # @param value [STObject, String, Array<Integer>, Hash] The value to convert.
    # @param filter [Proc, nil] Optional filter for fields.
    # @param definitions [Definitions, nil] Optional definitions.
    # @return [STObject] The created instance.
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

      # Use ::Hash explicitly to avoid shadowing by BinaryCodec::Hash
      unless value.is_a?(::Hash)
        raise StandardError, "STObject.from expects a Hash, got #{value.class}"
      end

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

      # Multisign special case: SigningPubKey should be empty if not provided or explicitly empty
      if processed_value['TransactionType'] && !processed_value.key?('SigningPubKey') && !processed_value.key?('TxnSignature')
         # This is an unsigned transaction, let's NOT add SigningPubKey yet.
         # Wait, xrpl.js adds it as empty when signing.
      end

      sorted_fields = processed_value.keys.map do |field_name|
        field = definitions.get_field_instance(field_name)
        raise "Field #{field_name} is not defined" if field.nil?
        field
      end.select(&:is_serialized).sort_by(&:ordinal)

      if filter
        sorted_fields = sorted_fields.select { |f| filter.call(f.name) }
      end

      sorted_fields.each do |field|
        associated_value = processed_value[field.name]
        next if associated_value.nil?

        # Special handling for SigningPubKey = "" during multisign
        # If the field is SigningPubKey and the value is "", it SHOULD still be serialized.
        # But wait, is_serialized for Blob (SigningPubKey) might be false if empty?
        # Actually, for SigningPubKey = "", it's 2 bytes: 73 (type 7 field 3) and 00 (length 0).
        
        # Special handling for UNLModify
        if field.name == 'UNLModify' # This might need more specific check depending on value
           is_unl_modify = true
        end
        is_unl_modify_workaround = (field.name == 'Account' && is_unl_modify)

        serializer.write_field_and_value(field, associated_value, is_unl_modify_workaround)
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
        begin
          field = parser.read_field
          break if field.name == OBJECT_END_MARKER

          associated_value = parser.read_field_value(field)

          bytes.write_field_and_value(field, associated_value)
          bytes.put(OBJECT_END_MARKER_BYTE) if field.type == ST_OBJECT
        rescue => e
          # If we fail to read a field (e.g. unknown header), we might have hit 
          # the end of the object without an end marker, or just malformed data.
          break
        end
      end

      STObject.new(list.to_bytes)
    end

    # Method to get the JSON interpretation of self.bytes
    #
    # @return [String] A stringified JSON object
    def to_json(_definitions = nil, _field_name = nil)
      definitions = _definitions || Definitions.instance
      parser = BinaryParser.new(to_hex)
      accumulator = {}

      until parser.end?
        begin
          # Check if we are at the end marker (0xE1) or if peek fails
          break if parser.peek == 0xE1
          
          field = parser.read_field
          break if field.name == 'ObjectEndMarker' # Break if the object end marker is reached
          
          # Special case: Blob fields might be empty (encoded as 0x00 length)
          if field.type == 'Blob' && !parser.end? && parser.peek == 0
            parser.read(1) # consume 0x00
            value = ""
          else
            value_obj = parser.read_field_value(field)
            value = value_obj.to_json(definitions, field.name)
            
            # Re-parse if it's a nested structure to keep it as a Hash/Array in the accumulator
            if field.type == 'STObject' || field.type == 'Amount' || field.type == 'STArray'
              value = JSON.parse(value) if value.is_a?(String)
            end
          end
          accumulator[field.name] = value
        rescue => e
          break
        end
      end

      # Existing tests expect a JSON string for STObject#to_json
      # To satisfy spec/binary-codec/types/st_object_spec.rb:10
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