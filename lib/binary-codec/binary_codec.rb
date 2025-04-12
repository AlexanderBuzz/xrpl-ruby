# frozen_string_literal: true

module BinaryCodec
  class BinaryCodec

    # from here: https://github.com/XRPLF/xrpl.js/blob/main/packages/ripple-binary-codec/src/binary.ts

    def make_parser(bytes, definitions = nil)
      BinaryParser.new(bytes.is_a?(String) ? bytes : bytes_to_hex(bytes))
    end

    #def read_json(parser, definitions = DEFAULT_DEFINITIONS)
    def read_json(parser)
      # parser.read_type(core_types[:STObject]).to_json(definitions)
      parser.read_type(core_types[:STObject]).to_json()
    end

    def binary_to_json(hex)
      parser = make_parser(hex)
      read_json(parser)
    end

    def serialize_object(obj, definitions = nil)
      BytesList.new.put_type(core_types[:STObject], obj)
    end

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
