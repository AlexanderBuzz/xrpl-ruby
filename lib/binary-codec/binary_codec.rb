# frozen_string_literal: true

require 'digest'

module BinaryCodec
  # Hash prefixes for serialization.
  HASH_PREFIX = {
    transaction_id: 0x54584E00, # 'TXN\0'
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

    # The ID of a transaction: SHA512Half of 'TXN\0' and its serialisation.
    # For a signed transaction that is its hash; for an unsigned one, such as
    # the inner transaction of a Batch, it is the ID rippled gives it.
    #
    # @param transaction [Hash, String] the transaction, or its serialisation as hex
    # @return [String] the ID, 64 uppercase hex characters
    def transaction_id(transaction)
      hex = transaction.is_a?(String) ? transaction : json_to_binary(transaction)
      prefix = int_to_bytes(HASH_PREFIX[:transaction_id], 4).pack('C*')
      Digest::SHA512.digest(prefix + [hex].pack('H*'))[0, 32].unpack1('H*').upcase
    end

    # The IDs of a Batch's inner transactions, in order.
    #
    # @param batch [Hash] the Batch
    # @return [Array<String>] one ID per entry of RawTransactions
    def inner_transaction_ids(batch)
      Array(batch['RawTransactions']).map do |wrapper|
        inner = wrapper.is_a?(::Hash) ? wrapper['RawTransaction'] : nil
        inner = inner.to_h if defined?(XRPL::Transaction) && inner.is_a?(XRPL::Transaction)
        raise ArgumentError, 'Every entry of RawTransactions needs a RawTransaction' unless inner.is_a?(::Hash)

        transaction_id(inner)
      end
    end

    # The bytes a BatchSigner signs over (rippled serializeBatch plus the
    # signer suffix, rippled 3.4.1 STTx::checkBatchSingleSign and
    # checkBatchMultiSign): 'BCH\0', the outer Account, the outer sequence
    # value, Flags, the number of inner transactions and their IDs, then the
    # BatchSigner's Account and, when multisigning, the signing account.
    #
    # Like encodeForSigningBatch in xrpl.js, this encodes what it is given: a
    # Batch without a Sequence encodes the sequence value 0. Wallet#sign_batch
    # refuses to sign one, because rippled requires the Sequence.
    #
    # @param batch [Hash] the Batch, with Account, Flags and its inner
    #   transactions complete
    # @param batch_account [String] the account of the BatchSigner entry
    # @param signer_account [String, nil] the account of the signer in the
    #   entry's Signers, when the entry is multisigned
    # @return [Array<Integer>] the signing data
    def signing_batch_data(batch, batch_account:, signer_account: nil)
      unless batch['Account'] && batch.key?('Flags')
        raise ArgumentError, 'A Batch needs Account and Flags before it can be signed'
      end

      ids = inner_transaction_ids(batch)
      bytes = int_to_bytes(HASH_PREFIX[:batch], 4) +
              account_bytes(batch['Account']) +
              int_to_bytes(batch_sequence_value(batch), 4) +
              int_to_bytes(Integer(batch['Flags']), 4) +
              int_to_bytes(ids.size, 4)
      ids.each { |id| bytes += hex_to_bytes(id) }
      bytes += account_bytes(batch_account)
      bytes += account_bytes(signer_account) if signer_account
      bytes
    end

    # rippled's SeqProxy value: the Sequence, or the TicketSequence when the
    # Sequence is 0 because a ticket is used.
    #
    # @param batch [Hash]
    # @return [Integer]
    def batch_sequence_value(batch)
      sequence = batch['Sequence'].to_i
      return sequence if sequence.positive?

      batch['TicketSequence'].to_i
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

    private

    def account_bytes(address)
      AddressCodec::AddressCodec.new.decode_account_id(address).to_a
    end
  end
end
