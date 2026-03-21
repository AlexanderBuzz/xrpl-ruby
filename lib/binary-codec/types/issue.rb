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

    def self.from_parser(parser, _hint = nil)
      bytes = []
      bytes.concat(parser.read(20)) # Currency
      # If there are more bytes in this field, it might have an issuer?
      # Actually Issue is often fixed length 20 or 40.
      # For XChainBridge it uses Issue.
      # Let's see how much we should read. 
      # Usually if it's an Issue in a field, we might know the size.
      # For now, let's assume it can be 20 or 40.
      # But wait, how does the parser know?
      # If it's not variable length, it must have a fixed width or be the rest of the object.
      # Definitions.json says Issue is type 24.
      bytes.concat(parser.read(20)) unless parser.end? # Try reading issuer
      Issue.new(bytes)
    end

    def to_json(_definitions = nil, _field_name = nil)
      parser = BinaryParser.new(to_hex)
      result = {}
      result['currency'] = Currency.from_parser(parser).to_json
      result['issuer'] = AccountId.from_parser(parser).to_json unless parser.end?
      result
    end
  end
end
