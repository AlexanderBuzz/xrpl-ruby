# frozen_string_literal: true

module BinaryCodec
  # Hash prefixes for serialization.
  HASH_PREFIX = {
    transaction_sig: 0x53545800, # 'STX\0'
    transaction_multi_sig: 0x534D5400, # 'SMT\0'
    validation: 0x56414C00, # 'VAL\0'
    proposal: 0x50525000, # 'PRP\0'
    payment_channel_claim: 0x434C4D00, # 'CLM\0'
    batch: 0x42434800, # 'BCH\0'
    # Role-specific prefixes from fixCleanup3_4_0, so a signature made for
    # one role cannot be replayed as another.
    counterparty_sig: 0x43505400, # 'CPT\0'
    counterparty_multi_sig: 0x43504D00, # 'CPM\0'
    sponsor_sig: 0x53504E00, # 'SPN\0'
    sponsor_multi_sig: 0x53504D00 # 'SPM\0'
  }.freeze

  # from here: https://github.com/XRPLF/xrpl.js/blob/main/packages/ripple-binary-codec/src/binary.ts
  class << self
    # Creates a BinaryParser for the given bytes.
    # @param bytes [String, Array<Integer>] The bytes to parse (hex string or byte array).
    # @param definitions [Definitions, nil] Optional definitions.
    # @return [BinaryParser] The created parser.
    def make_parser(bytes, definitions = nil)
      BinaryParser.new(bytes.is_a?(String) ? bytes : bytes_to_hex(bytes))
    end

    # Converts a hex string to its JSON representation.
    # @param hex [String] The hex string to convert.
    # @return [Hash] The decoded JSON object.
    def binary_to_json(hex)
      parser = make_parser(hex)
      st_object = SerializedType.get_type_by_name('STObject')
      result = st_object.from_parser(parser).to_json
      result = JSON.generate(result) unless result.is_a?(String)
      JSON.parse(result)
    end

    # Converts a JSON object to its binary representation.
    # @param json [Hash] The JSON object to convert.
    # @return [String] The serialized hex string.
    def json_to_binary(json)
      st_object = SerializedType.get_type_by_name('STObject')
      st_object.from(json).to_hex
    end

    # The bytes a payment channel claim is signed over: the 'CLM\0' prefix,
    # the channel ID and the amount in drops. Same as xrpl.js
    # encodeForSigningClaim.
    #
    # @param channel [String] the channel ID, 64 hex characters
    # @param amount [String, Integer] the amount in drops
    # @return [Array<Integer>] the signing data
    def signing_claim_data(channel:, amount:)
      int_to_bytes(HASH_PREFIX[:payment_channel_claim], 4) +
        Hash256.from(channel).to_bytes +
        Uint64.from(Integer(amount)).to_bytes
    end

    # Generates signing data for a transaction.
    # @param transaction [Hash] The transaction to serialize.
    # @param prefix [Integer] The prefix to add to the serialized data.
    # @param opts [Hash] Optional settings (e.g., :definitions, :signing_fields_only).
    # @return [Array<Integer>] The serialized signing data.
    def signing_data(transaction, prefix = HASH_PREFIX[:transaction_sig], opts = {})
      # 1. Start with the prefix bytes
      prefix_bytes = int_to_bytes(prefix, 4)

      # 2. Serialize the object, only including signing fields
      st_object_class = SerializedType.get_type_by_name('STObject')

      filter = if opts[:signing_fields_only]
                 lambda { |field_name| Definitions.instance.get_field_instance(field_name).is_signing_field }
               else
                 nil
               end

      serialized_bytes = st_object_class.from(transaction, filter).to_bytes

      prefix_bytes + serialized_bytes
    end
  end
end
