# frozen_string_literal: true

module XRPL
  # Prepares the inner transactions of a Batch (XLS-56) before it is signed.
  #
  # The ledger requires every inner transaction to carry the tfInnerBatchTxn
  # flag, a Fee of "0" and an empty SigningPubKey: the outer transaction pays
  # the fees, and the outer signature together with BatchSigners authorises
  # the inner transactions. They must also carry their final Sequence, because
  # the BatchSigners sign over the inner transaction IDs. So the Batch has to
  # be complete before anyone signs it.
  #
  # The module is pure: XRPL::Client#autofill passes in a way to fetch an
  # account's sequence. What the ledger would refuse is refused here, before
  # anything is signed or sent.
  module Batch
    FLAGS = Model::DEFINITIONS['TRANSACTION_FLAGS']

    # The four modes; a Batch names exactly one of them.
    MODE_FLAGS = FLAGS.fetch('Batch').values.reduce(0, :|)

    # Marks a transaction as the inner transaction of a Batch.
    TF_INNER_BATCH_TXN = FLAGS.fetch('universal').fetch('tfInnerBatchTxn')

    MIN_INNER = 2
    MAX_INNER = 8

    module_function

    # @param batch [Hash] the Batch, with its outer Sequence (or
    #   TicketSequence) already set; it is not modified
    # @param sequence_for [#call] takes an account and returns its next
    #   sequence; only called for accounts whose inner transactions lack a
    #   Sequence and a TicketSequence, once per account
    # @return [Hash] a copy of the Batch with its inner transactions filled in
    # @raise [ArgumentError] when the ledger would refuse the Batch
    def prepare(batch, sequence_for:)
      check_mode!(batch['Flags'])
      raw = batch['RawTransactions']
      unless raw.is_a?(Array) && raw.size.between?(MIN_INNER, MAX_INNER)
        count = raw.is_a?(Array) ? raw.size : 0
        raise ArgumentError, "A Batch carries #{MIN_INNER} to #{MAX_INNER} inner transactions, this one has #{count}"
      end

      next_sequence = {}
      prepared = raw.each_with_index.map do |wrapper, index|
        inner = unwrap(wrapper, index)
        check_inner!(inner, index)

        inner['Flags'] = Integer(inner['Flags'] || 0) | TF_INNER_BATCH_TXN
        inner['Fee'] = '0'
        inner['SigningPubKey'] = ''

        if inner['Sequence'].nil? && inner['TicketSequence'].nil?
          account = inner.fetch('Account') do
            raise ArgumentError, "RawTransactions[#{index}] has no Account"
          end
          next_sequence[account] ||= first_sequence(batch, account, sequence_for)
          inner['Sequence'] = next_sequence[account]
          next_sequence[account] += 1
        end

        { 'RawTransaction' => inner }
      end

      batch.merge('RawTransactions' => prepared)
    end

    # The number of signatures a BatchSigners array carries: one per entry,
    # or, for an entry signed by a signer list, one per nested signer.
    #
    # @param batch_signers [Array<Hash>, nil]
    # @return [Integer]
    def signature_count(batch_signers)
      Array(batch_signers).sum do |entry|
        signer = entry.is_a?(Hash) ? (entry['BatchSigner'] || entry) : {}
        nested = signer['Signers']
        nested.is_a?(Array) && !nested.empty? ? nested.size : 1
      end
    end

    def check_mode!(flags)
      mode = Integer(flags || 0) & MODE_FLAGS
      return if mode.positive? && (mode & (mode - 1)).zero?

      raise ArgumentError, 'A Batch needs exactly one of tfAllOrNothing, tfOnlyOne, ' \
                           'tfUntilFailure and tfIndependent in Flags'
    end

    def unwrap(wrapper, index)
      inner = wrapper.is_a?(Hash) && wrapper.keys == ['RawTransaction'] ? wrapper['RawTransaction'] : nil
      inner = inner.to_h if inner.is_a?(XRPL::Transaction)
      unless inner.is_a?(Hash)
        raise ArgumentError, "RawTransactions[#{index}] must be { 'RawTransaction' => transaction }"
      end

      inner.dup
    end

    def check_inner!(inner, index)
      prefix = "RawTransactions[#{index}]"
      raise ArgumentError, "#{prefix} is a Batch; a Batch cannot nest" if inner['TransactionType'] == 'Batch'
      if inner.key?('TxnSignature') || inner.key?('Signers')
        raise ArgumentError, "#{prefix} must not be signed; the Batch is signed as a whole"
      end
      if inner.key?('Fee') && inner['Fee'].to_s != '0'
        raise ArgumentError, "#{prefix} must have Fee \"0\"; the Batch pays the fees"
      end
      return unless inner.key?('SigningPubKey') && inner['SigningPubKey'].to_s != ''

      raise ArgumentError, "#{prefix} must have an empty SigningPubKey"
    end

    # The outer account's inner transactions follow the outer one, which
    # consumes its Sequence; when it uses a ticket instead, the account's
    # sequence is still free. Every other account starts at its own.
    def first_sequence(batch, account, sequence_for)
      outer_sequence = batch['Sequence'].to_i
      if account == batch['Account'] && outer_sequence.positive? && batch['TicketSequence'].nil?
        outer_sequence + 1
      else
        Integer(sequence_for.call(account))
      end
    end

    private_class_method :check_mode!, :unwrap, :check_inner!, :first_sequence
  end
end
