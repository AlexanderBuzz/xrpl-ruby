# frozen_string_literal: true

module BinaryCodec
  class PathSet < SerializedType
    PATH_STEP_END_MARKER = 0xFF
    PATH_END_MARKER = 0xFE

    TYPE_ACCOUNT = 0x01
    TYPE_CURRENCY = 0x10
    TYPE_ISSUER = 0x20

    def initialize(bytes = nil)
      super(bytes || [])
    end

    def self.from(value)
      return value if value.is_a?(PathSet)

      if value.is_a?(String)
        return PathSet.new(hex_to_bytes(value))
      end

      if value.is_a?(::Array)
        bytes = []
        value.each_with_index do |path, index|
          path.each do |step|
            type = 0
            step_bytes = []

            if step['account']
              type |= TYPE_ACCOUNT
              step_bytes.concat(AccountId.from(step['account']).to_bytes)
            end
            if step['currency']
              type |= TYPE_CURRENCY
              step_bytes.concat(Currency.from(step['currency']).to_bytes)
            end
            if step['issuer']
              type |= TYPE_ISSUER
              step_bytes.concat(AccountId.from(step['issuer']).to_bytes)
            end

            bytes << type
            bytes.concat(step_bytes)
          end
          bytes << (index == value.length - 1 ? PATH_END_MARKER : PATH_STEP_END_MARKER)
        end
        return PathSet.new(bytes)
      end

      raise StandardError, "Cannot construct PathSet from #{value.class}"
    end

    def self.from_parser(parser, _hint = nil)
      bytes = []
      loop do
        type = parser.read_uint8
        bytes << type
        break if type == PATH_END_MARKER

        if type != PATH_STEP_END_MARKER
          bytes.concat(parser.read(20)) if (type & TYPE_ACCOUNT) != 0
          bytes.concat(parser.read(20)) if (type & TYPE_CURRENCY) != 0
          bytes.concat(parser.read(20)) if (type & TYPE_ISSUER) != 0
        end
      end
      PathSet.new(bytes)
    end

    def to_json(_definitions = nil, _field_name = nil)
      parser = BinaryParser.new(to_hex)
      paths = []
      current_path = []

      until parser.end?
        type = parser.read_uint8
        if type == PATH_END_MARKER || type == PATH_STEP_END_MARKER
          paths << current_path
          current_path = []
          break if type == PATH_END_MARKER
          next
        end

        step = {}
        step['account'] = AccountId.from_parser(parser).to_json if (type & TYPE_ACCOUNT) != 0
        step['currency'] = Currency.from_parser(parser).to_json if (type & TYPE_CURRENCY) != 0
        step['issuer'] = AccountId.from_parser(parser).to_json if (type & TYPE_ISSUER) != 0
        current_path << step
      end
      paths
    end
  end
end
