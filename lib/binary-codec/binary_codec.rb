# frozen_string_literal: true

module BinaryCodec
  class BinaryCodec

    # from here: https://github.com/XRPLF/xrpl.js/blob/main/packages/ripple-binary-codec/src/binary.ts

    # Creates a BinaryParser for the given bytes.
    # @param bytes [String, Array<Integer>] The bytes to parse (hex string or byte array).
    # @param definitions [Definitions, nil] Optional definitions.
    # @return [BinaryParser] The created parser.
    def make_parser(bytes, definitions = nil)
      BinaryParser.new(bytes.is_a?(String) ? bytes : bytes_to_hex(bytes))
    end

    #def read_json(parser, definitions = DEFAULT_DEFINITIONS)
    # Reads a JSON representation from a parser.
    # @param parser [BinaryParser] The parser to read from.
    # @return [Hash] The decoded JSON object.
    def read_json(parser)
      # parser.read_type(core_types[:STObject]).to_json(definitions)
      parser.read_type(core_types[:STObject]).to_json()
    end

    # Converts a hex string to its JSON representation.
    # @param hex [String] The hex string to convert.
    # @return [Hash] The decoded JSON object.
    def binary_to_json(hex)
      parser = make_parser(hex)
      read_json(parser)
    end

    # Serializes an object into a BytesList.
    # @param obj [Hash] The object to serialize.
    # @param definitions [Definitions, nil] Optional definitions.
    # @return [BytesList] The serialized bytes.
    def serialize_object(obj, definitions = nil)
      BytesList.new.put_type(core_types[:STObject], obj)
    end

    # Generates signing data for a transaction.
    # @param transaction [Hash] The transaction to serialize.
    # @param prefix [Integer] The prefix to add to the serialized data.
    # @param opts [Hash] Optional settings (e.g., :definitions).
    # @return [Array<Integer>] The serialized signing data.
    def signing_data(transaction, prefix = HashPrefix[:transaction_sig], opts = {})
      serialize_object(
        transaction,
        prefix: prefix,
        signing_fields_only: true,
        definitions: opts[:definitions]
      )
    end

  end

end
