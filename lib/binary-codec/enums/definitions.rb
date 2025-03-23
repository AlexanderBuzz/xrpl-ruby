# frozen_string_literal: true
require 'json'

module BinaryCodec

  class Definitions

    # attr_reader :type_ordinals, :ledger_entry_types, :transaction_results, :transaction_types, :field_info_map, :field_id_name_map, :field_header_map

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
        field_header = FieldHeader.new(type: @type_ordinals[field_info.type], nth: field_info.nth)

        @field_info_map[field_name] = field_info
        @field_id_name_map[Digest::MD5.hexdigest(Marshal.dump(field_header))] = field_name
        @field_header_map[field_name] = field_header
      end

    rescue Errno::ENOENT
      raise "Error: The file '#{file_path}' was not found. Please ensure the file exists."
    rescue JSON::ParserError => e
      raise "Error: The file '#{file_path}' contains invalid JSON: #{e.message}"

     end

     def get_field_header_from_name(field_name)
       @field_header_map[field_name]
     end

     def get_field_name_from_header(field_header)
       @field_id_name_map[Digest::MD5.hexdigest(Marshal.dump(field_header))]
     end

     def get_field_instance(field_name)
       field_info = @field_info_map[field_name]
       field_header = get_field_header_from_name(field_name)

       FieldInstance.new(
         nth: field_info.nth,
         is_variable_length_encoded: field_info.is_vl_encoded,
         is_serialized: field_info.is_serialized,
         is_signing_field: field_info.is_signing_field,
         type: field_info.type,
         ordinal: (field_header.type << 16) | field_info.nth, # @type_ordinals[field_info.type],
         name: field_name,
         header: field_header,
         associated_type: field_info.type # SerializedType::getTypeByName($this->type)::class;
       )
     end

  end

end
