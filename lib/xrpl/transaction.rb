# frozen_string_literal: true

module XRPL
  # A transaction, built from the field formats in definitions.json.
  #
  # The subclasses are not written by hand: one is created for each entry in
  # TRANSACTION_FORMATS when this file loads, so syncing definitions.json
  # updates the models with it and they cannot drift from the ledger.
  #
  #     tx = XRPL::Transaction::Payment.new(
  #       account: wallet.classic_address,
  #       destination: receiver.classic_address,
  #       amount: '1000000'
  #     )
  #     tx.validate!
  #     client.submit_and_wait(tx, wallet: wallet)
  #
  # Fields are given in snake_case and stored under the ledger's own PascalCase
  # names, so #to_h hands the binary codec exactly what it expects. A plain
  # Hash still works everywhere a transaction is accepted; these classes are an
  # addition, not a replacement. The machinery lives in XRPL::Model and is
  # shared with XRPL::LedgerEntry.
  class Transaction < Model
    # Fields every transaction carries, regardless of type.
    COMMON_FORMAT = DEFINITIONS['TRANSACTION_FORMATS'].fetch('common').freeze

    # Required by the format, but supplied by autofill and signing rather than
    # by the caller. Demanding them up front would make #validate! useless at
    # the point where it is actually worth running.
    SUPPLIED_LATER = %w[
      TransactionType Sequence Fee SigningPubKey TxnSignature LastLedgerSequence
    ].freeze

    class << self
      # The ledger's name for this transaction type, e.g. "Payment".
      alias transaction_type type_name

      def type_field
        'TransactionType'
      end

      def label
        'transaction'
      end

      def supplied_later
        SUPPLIED_LATER
      end
    end

    define_types!(DEFINITIONS['TRANSACTION_FORMATS'], DEFINITIONS['TRANSACTION_FLAGS'])
  end
end
