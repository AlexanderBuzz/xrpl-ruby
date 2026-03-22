# frozen_string_literal: true
require 'json'
require 'digest'

module BinaryCodec

  class Definitions

    @@instance = nil

     def initialize
      file_path = File.join(__dir__, 'definitions.json') #
      contents = File.read(file_path)
      @definitions = JSON.parse(contents)

      @type_ordinals = @definitions['TYPES']
      @ledger_entry_types = @definitions['LEDGER_ENTRY_TYPES']
      @transaction_results = @definitions['TRANSACTION_RESULTS']
      @transaction_types = @definitions['TRANSACTION_TYPES']

      @field_info_map = {}
      @field_id_name_map = {}
      @field_header_map = {}

      @definitions['FIELDS'].each do |field|
        field_name = field[0]
        field_info = FieldInfo.new(
          nth: field[1]['nth'],
          is_vl_encoded: field[1]['isVLEncoded'],
          is_serialized: field[1]['isSerialized'],
          is_signing_field: field[1]['isSigningField'],
          type: field[1]['type']
        )
        type_ordinal = @type_ordinals[field_info.type]
        field_header = FieldHeader.new(type: type_ordinal, nth: field_info.nth)

        @field_info_map[field_name] = field_info
        key = (type_ordinal << 16) | field_info.nth
        @field_id_name_map[key] = field_name
        @field_header_map[field_name] = field_header
      end

    rescue Errno::ENOENT
      raise "Error: The file '#{file_path}' was not found. Please ensure the file exists."
    rescue JSON::ParserError => e
      raise "Error: The file '#{file_path}' contains invalid JSON: #{e.message}"

     end

    # Returns the singleton instance of the Definitions class.
    # @return [Definitions] The singleton instance.
    def self.instance
      @@instance ||= new
    end

    # Returns the field header for a given field name.
    # @param field_name [String] The name of the field.
    # @return [FieldHeader] The field header.
    def get_field_header_from_name(field_name)
       @field_header_map[field_name]
     end

    # Returns the field name for a given field header.
    # @param field_header [FieldHeader] The field header.
    # @return [String] The name of the field.
    def get_field_name_from_header(field_header)
       @field_id_name_map[(field_header.type << 16) | field_header.nth]
    end

    # Returns a FieldInstance for a given field name.
    # @param field_name [String] The name of the field.
    # @return [FieldInstance] The field instance.
    def get_field_instance(field_name)
       field_info = @field_info_map[field_name]
       field_header = get_field_header_from_name(field_name)

       FieldInstance.new(
         nth: field_info.nth,
         is_variable_length_encoded: field_info.is_vl_encoded,
         is_serialized: field_info.is_serialized,
         is_signing_field: field_info.is_signing_field,
         type: field_info.type,
         ordinal: (@type_ordinals[field_info.type] << 16) | field_info.nth,
         name: field_name,
         header: field_header,
         associated_type: SerializedType.get_type_by_name(field_info.type)
       )
     end

  end

end
