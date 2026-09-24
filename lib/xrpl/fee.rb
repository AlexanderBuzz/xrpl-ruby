# frozen_string_literal: true

module XRPL
  # The fee a transaction needs, in drops, by transaction type.
  #
  # rippled charges most transactions the network's base fee, but not all of
  # them: an EscrowFinish pays for the size of its Fulfillment, AccountDelete,
  # AMMCreate and VaultCreate cost an owner reserve rather than a fee, a Batch
  # pays for its inner transactions, and the confidential MPT transactions
  # cost ten base fees. Multisigning adds one base fee per signature. The
  # rules are the ones xrpl.js applies in its autofill.
  #
  # This module is pure: it takes the base fee and, when a type needs it, a
  # way to get the owner reserve. XRPL::Client wires it to the ledger.
  module Fee
    # Where an ordinary fee is capped, so that a spike in the open ledger fee
    # cannot burn an account. The reserve-priced types are not capped: their
    # cost is what it is.
    MAX_FEE_DROPS = 2_000_000

    # Types whose cost is the owner reserve (reserve_inc), not a fee.
    RESERVE_PRICED = %w[AccountDelete AMMCreate VaultCreate].freeze

    # rippled's kCONFIDENTIAL_FEE_MULTIPLIER: extra base fees on top of the
    # standard one, so ten in total.
    CONFIDENTIAL_MPT_MULTIPLIER = 9

    CONFIDENTIAL_MPT_TYPES = %w[
      ConfidentialMPTConvert ConfidentialMPTConvertBack ConfidentialMPTSend
      ConfidentialMPTClawback ConfidentialMPTMergeInbox
    ].freeze

    module_function

    # @param transaction [Hash, XRPL::Transaction] the transaction, with its
    #   TransactionType
    # @param base_fee [Integer] the network's base fee in drops
    # @param signers_count [Integer] number of signatures for multisign scaling
    # @param max_fee [Integer] cap for ordinary fees
    # @param owner_reserve [Integer, #call, nil] the owner reserve in drops,
    #   or something that fetches it; only consulted for the reserve-priced
    #   types
    # @return [Integer] the fee in drops, rounded up
    def calculate(transaction, base_fee:, signers_count: 0, max_fee: MAX_FEE_DROPS, owner_reserve: nil)
      tx = transaction.respond_to?(:to_h) ? transaction.to_h : transaction
      type = tx['TransactionType'] || tx[:TransactionType]
      base_fee = Integer(base_fee)

      fee = Rational(base_fee)
      reserve_priced = RESERVE_PRICED.include?(type)

      if type == 'EscrowFinish' && tx['Fulfillment']
        # Base fee × (33 + Fulfillment size in bytes / 16)
        bytes = (tx['Fulfillment'].to_s.length + 1) / 2
        fee = base_fee * (33 + Rational(bytes, 16))
      elsif reserve_priced
        fee = Rational(resolve_owner_reserve(owner_reserve, type))
      elsif type == 'Batch'
        inner = Array(tx['RawTransactions']).sum(0r) do |raw|
          calculate(raw['RawTransaction'] || raw, base_fee: base_fee, max_fee: max_fee,
                                                  owner_reserve: owner_reserve)
        end
        fee = base_fee * 2 + inner
      elsif CONFIDENTIAL_MPT_TYPES.include?(type)
        fee += base_fee * CONFIDENTIAL_MPT_MULTIPLIER
      end

      # Multisigned: base fee × (1 + number of signatures)
      fee += base_fee * signers_count if signers_count.to_i.positive?

      fee = [fee, Rational(max_fee)].min unless reserve_priced
      fee.ceil
    end

    def resolve_owner_reserve(owner_reserve, type)
      reserve = owner_reserve.respond_to?(:call) ? owner_reserve.call : owner_reserve
      raise ArgumentError, "#{type} costs the owner reserve, which was not given" if reserve.nil?

      Integer(reserve)
    end
  end
end
