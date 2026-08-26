# frozen_string_literal: true

module BinaryCodec
  # An asset without an amount: XRP, an issued token, or an MPT.
  #
  # The width is not fixed, and it cannot be supplied from outside. XRP is the
  # 20 byte currency code on its own, an issued token adds the 20 byte issuer,
  # and an MPT carries the issuer, a reserved placeholder and the four byte
  # issuance sequence. Only the currency code says which of the three it is, so
  # the parser has to read that before it knows how much to consume.
  #
  # This class used to take a size hint and read a flat 40 bytes, which for an
  # XRP issue swallowed the field that follows - that is why every AMM and
  # XChain fixture decoded with a nil Asset or the wrong door account.
  class Issue < SerializedType
    CURRENCY_LENGTH = 20
    ISSUER_LENGTH = 20
    SEQUENCE_LENGTH = 4
    MPT_LENGTH = CURRENCY_LENGTH + ISSUER_LENGTH + SEQUENCE_LENGTH

    # The reserved "no account" value. Sitting in the issuer slot, it marks the
    # issue as an MPT rather than as a token issued by that account.
    NO_ACCOUNT = '0000000000000000000000000000000000000001'

    def initialize(bytes = nil)
      super(bytes || [])
    end

    def self.from(value)
      return value if value.is_a?(Issue)
      return Issue.new(hex_to_bytes(value)) if value.is_a?(String)

      unless value.is_a?(::Hash)
        raise StandardError, "Cannot construct Issue from #{value.class}"
      end

      return Issue.new(mpt_bytes(value['mpt_issuance_id'])) if value['mpt_issuance_id']

      bytes = Currency.from(value['currency']).to_bytes
      bytes += AccountId.from(value['issuer']).to_bytes if value['issuer']
      Issue.new(bytes)
    end

    # An MPT issuance id is the issuance sequence followed by the issuer. The
    # sequence is big endian there but little endian on the wire.
    def self.mpt_bytes(issuance_id)
      id = hex_to_bytes(issuance_id)
      sequence = id[0, SEQUENCE_LENGTH]
      issuer = id[SEQUENCE_LENGTH..]

      issuer + hex_to_bytes(NO_ACCOUNT) + sequence.reverse
    end
    private_class_method :mpt_bytes

    # The size hint is accepted and ignored: callers cannot know the width, and
    # passing one in is how the fixed 40 byte read came about.
    def self.from_parser(parser, _size_hint = nil)
      return Issue.new([]) if parser.end?

      currency = parser.read(CURRENCY_LENGTH)
      return Issue.new(currency) if Currency.new(currency).to_json == 'XRP'

      issuer = parser.read(ISSUER_LENGTH)
      bytes = currency + issuer
      bytes += parser.read(SEQUENCE_LENGTH) if bytes_to_hex(issuer).upcase == NO_ACCOUNT

      Issue.new(bytes)
    end

    def to_json(_definitions = nil, _field_name = nil)
      return { 'mpt_issuance_id' => mpt_issuance_id } if to_bytes.length == MPT_LENGTH

      parser = BinaryParser.new(to_hex)
      currency = Currency.from_parser(parser).to_json

      # An XRP issue has no issuer. Reporting one means 20 bytes of the next
      # field were read as an account.
      return { 'currency' => currency } if currency == 'XRP'

      { 'currency' => currency, 'issuer' => AccountId.from_parser(parser).to_json }
    end

    private

    def mpt_issuance_id
      issuer = to_bytes[0, ISSUER_LENGTH]
      sequence = to_bytes[CURRENCY_LENGTH + ISSUER_LENGTH, SEQUENCE_LENGTH].reverse

      bytes_to_hex(sequence + issuer).upcase
    end
  end
end
