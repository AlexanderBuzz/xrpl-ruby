# frozen_string_literal: true

module BinaryCodec
  class XChainBridge < SerializedType
    def initialize(bytes = nil)
      super(bytes || [])
    end

    def self.from(value)
      return value if value.is_a?(XChainBridge)

      if value.is_a?(String)
        return XChainBridge.new(hex_to_bytes(value))
      end

      if value.is_a?(Hash)
        bytes = []
        bytes.concat(AccountId.from(value['LockingChainDoor']).to_bytes)
        bytes.concat(Issue.from(value['LockingChainIssue']).to_bytes)
        bytes.concat(AccountId.from(value['IssuingChainDoor']).to_bytes)
        bytes.concat(Issue.from(value['IssuingChainIssue']).to_bytes)
        return XChainBridge.new(bytes)
      end

      raise StandardError, "Cannot construct XChainBridge from #{value.class}"
    end

    def self.from_parser(parser, _hint = nil)
      bytes = []
      bytes.concat(parser.read(20)) # LockingChainDoor
      bytes.concat(Issue.from_parser(parser).to_bytes) # LockingChainIssue
      bytes.concat(parser.read(20)) # IssuingChainDoor
      bytes.concat(Issue.from_parser(parser).to_bytes) # IssuingChainIssue
      XChainBridge.new(bytes)
    end

    def to_json(_definitions = nil, _field_name = nil)
      parser = BinaryParser.new(to_hex)
      result = {}
      result['LockingChainDoor'] = AccountId.from_parser(parser).to_json
      result['LockingChainIssue'] = Issue.from_parser(parser).to_json
      result['IssuingChainDoor'] = AccountId.from_parser(parser).to_json
      result['IssuingChainIssue'] = Issue.from_parser(parser).to_json
      result
    end
  end
end
