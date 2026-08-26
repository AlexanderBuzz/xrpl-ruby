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

      if value.is_a?(::Hash)
        bytes = []
        bytes.concat(door_bytes(value['LockingChainDoor']))
        bytes.concat(Issue.from(value['LockingChainIssue']).to_bytes)
        bytes.concat(door_bytes(value['IssuingChainDoor']))
        bytes.concat(Issue.from(value['IssuingChainIssue']).to_bytes)
        return XChainBridge.new(bytes)
      end

      raise StandardError, "Cannot construct XChainBridge from #{value.class}"
    end

    # An account inside a bridge carries the same length prefix as a
    # standalone AccountID field. Leaving it off produces bytes that decode
    # as something else entirely, which is why every XChain fixture failed
    # to serialise.
    DOOR_LENGTH_PREFIX = 0x14

    def self.door_bytes(account)
      [DOOR_LENGTH_PREFIX] + AccountId.from(account).to_bytes
    end
    private_class_method :door_bytes

    def self.from_parser(parser, _hint = nil)
      bytes = []
      bytes.concat(parser.read(1)) # length prefix
      bytes.concat(parser.read(20)) # LockingChainDoor
      bytes.concat(Issue.from_parser(parser, 40).to_bytes) # LockingChainIssue
      bytes.concat(parser.read(1)) # length prefix
      bytes.concat(parser.read(20)) # IssuingChainDoor
      bytes.concat(Issue.from_parser(parser, 40).to_bytes) # IssuingChainIssue
      XChainBridge.new(bytes)
    end

    def to_json(_definitions = nil, _field_name = nil)
      parser = BinaryParser.new(to_hex)
      result = {}
      parser.read(1) # length prefix
      result['LockingChainDoor'] = AccountId.from_parser(parser).to_json
      result['LockingChainIssue'] = Issue.from_parser(parser, 40).to_json
      parser.read(1) # length prefix
      result['IssuingChainDoor'] = AccountId.from_parser(parser).to_json
      result['IssuingChainIssue'] = Issue.from_parser(parser, 40).to_json
      result
    end
  end
end
