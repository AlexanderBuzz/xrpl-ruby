# frozen_string_literal: true

module BinaryCodec

  class FieldHeader

    attr_reader :type, :nth

    def initialize(type:, nth:)
      @type = type
      @nth = nth
    end

    def to_bytes
      header = []
      if type < 16
        if nth < 16
          header.push((type << 4) | nth)
        else
          header.push(type << 4, nth)
        end
      elsif nth < 16
        header.push(nth,type)
      else
        header.push(0, type, nth)
      end

      header
    end

  end
  class FieldInfo

    attr_reader :nth, :is_vl_encoded, :is_serialized, :is_signing_field, :type

    def initialize(nth:, is_vl_encoded:, is_serialized:, is_signing_field:, type:)
      @nth = nth
      @is_vl_encoded = is_vl_encoded
      @is_serialized = is_serialized
      @is_signing_field = is_signing_field
      @type = type
    end

  end

  class FieldInstance

    attr_reader :nth, :is_variable_length_encoded, :is_serialized, :is_signing_field, :type, :ordinal, :name, :header, :associated_type

    def initialize(nth:, is_variable_length_encoded:, is_serialized:, is_signing_field:, type:, ordinal:, name:, header:, associated_type:)
      @nth = nth
      @is_variable_length_encoded = is_variable_length_encoded
      @is_serialized = is_serialized
      @is_signing_field = is_signing_field
      @type = type
      @ordinal = ordinal
      @name = name
      @header = header
      @associated_type = associated_type
    end

  end

  # TODO: See if this makes sense or if Ruby hashes are just fine
  class FieldLookup
    def initialize(fields:, types:)
      @fields_hash = {}

      fields.each do |name, field_info|
        type_ordinal = types[field_info.type]
        field = build_field([name, field_info], type_ordinal) # Store the built field
        @fields_hash[name] = field                           # Map field by name
        @fields_hash[field.ordinal.to_s] = field             # Map field by ordinal
      end
    end

    # Method to retrieve a FieldInstance by its string key
    def from_string(value)
      @fields_hash[value]
    end

    private

    # Dummy build_field method (must be implemented elsewhere)
    def build_field(field, type_ordinal)
      field_header = FieldHeader.new(type: field[1].type, nth: field[1].nth)
      FieldInstance.new(
        nth: field[1].nth,
        is_variable_length_encoded: field[1].is_vl_encoded,
        is_serialized: field[1].is_serialized,
        is_signing_field: field[1].is_signing_field,
        type: field[1].type,
        ordinal: type_ordinal,
        name: field[0],
        header: field_header,
        associated_type: SerializedType
        #associated_type: SerializedType.get_type_by_name(field[1].type)
      )
    end
  end

end