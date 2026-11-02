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
      check_sequence_and_ticket!(batch, 'The Batch')
      raw = batch['RawTransactions']
      unless raw.is_a?(Array) && raw.size.between?(MIN_INNER, MAX_INNER)
        count = raw.is_a?(Array) ? raw.size : 0
        raise ArgumentError, "A Batch carries #{MIN_INNER} to #{MAX_INNER} inner transactions, this one has #{count}"
      end

      # Per account: the next sequence to hand out, and the lowest one still
      # free after the explicit sequences seen so far. An inner transaction
      # without a sequence gets the higher of the two, so it never repeats
      # one given explicitly earlier in the Batch.
      next_sequence = {}
      floor = Hash.new(0)
      take = lambda do |account|
        [next_sequence[account] || first_sequence(batch, account, sequence_for), floor[account]].max
      end

      prepared = raw.each_with_index.map do |wrapper, index|
        inner = unwrap(wrapper, index)
        check_inner!(inner, index)

        inner['Flags'] = Integer(inner['Flags'] || 0) | TF_INNER_BATCH_TXN
        inner['Fee'] = '0'
        inner['SigningPubKey'] = ''

        account = inner.fetch('Account') do
          raise ArgumentError, "RawTransactions[#{index}] has no Account"
        end
        # A TicketCreate also takes a sequence for every ticket it creates.
        reserved = inner['TransactionType'] == 'TicketCreate' ? Integer(inner['TicketCount'] || 0) : 0

        if !inner['TicketSequence'].nil? && inner['Sequence'].to_i.zero?
          # On a ticket: Sequence is a required field and 0 here. Only a
          # TicketCreate still moves the account's sequence on, by the
          # tickets it creates, starting at the current one.
          inner['Sequence'] = 0
          next_sequence[account] = take.call(account) + reserved if reserved.positive?
        elsif inner['Sequence'].nil?
          sequence = take.call(account)
          inner['Sequence'] = sequence
          next_sequence[account] = sequence + 1 + reserved
        else
          floor[account] = [floor[account], Integer(inner['Sequence']) + 1 + reserved].max
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

    # On a ticket, Sequence is 0; rippled refuses a nonzero Sequence next to
    # a TicketSequence (temSEQ_AND_TICKET). Refused before any sequence is
    # handed out, so it cannot push the account's later sequences up.
    def check_sequence_and_ticket!(transaction, label)
      return if transaction['TicketSequence'].nil? || transaction['Sequence'].to_i.zero?

      raise ArgumentError, "#{label} has both a Sequence and a TicketSequence; " \
                           'on a ticket, Sequence is 0 (temSEQ_AND_TICKET)'
    end

    def check_inner!(inner, index)
      prefix = "RawTransactions[#{index}]"
      check_sequence_and_ticket!(inner, prefix)
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

    private_class_method :check_mode!, :check_sequence_and_ticket!, :unwrap, :check_inner!, :first_sequence
  end
end
