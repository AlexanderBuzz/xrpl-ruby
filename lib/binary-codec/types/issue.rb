# frozen_string_literal: true

module BinaryCodec
  class Issue < SerializedType
    def initialize(bytes = nil)
      super(bytes || [])
    end

    def self.from(value)
      return value if value.is_a?(Issue)

      if value.is_a?(String)
        return Issue.new(hex_to_bytes(value))
      end

      if value.is_a?(Hash) || value.is_a?(::Hash)
        bytes = []
        bytes.concat(Currency.from(value['currency']).to_bytes)
        bytes.concat(AccountId.from(value['issuer']).to_bytes) if value['issuer']
        return Issue.new(bytes)
      end

      raise StandardError, "Cannot construct Issue from #{value.class}"
    end

    def self.from_parser(parser, size_hint = nil)
      bytes = []
      return Issue.new(bytes) if parser.end?
      bytes.concat(parser.read(20)) # Currency
      unless parser.end? || (size_hint && size_hint <= 20)
        bytes.concat(parser.read(20))
      end
      Issue.new(bytes)
    end

    def to_json(_definitions = nil, _field_name = nil)
      parser = BinaryParser.new(to_hex)
      result = {}
      result['currency'] = Currency.from_parser(parser).to_json
      result['issuer'] = AccountId.from_parser(parser).to_json unless parser.end?
      result
    rescue
      # Fallback for partial/invalid binary
      { 'currency' => Currency.new(to_bytes[0, 20]).to_json }
    end
  end
end
