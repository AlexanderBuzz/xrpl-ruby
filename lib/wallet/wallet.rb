# frozen_string_literal: true

require 'digest'
require 'openssl'

module Wallet
  # Represents an XRPL wallet, providing methods for signing and address derivation.
  class Wallet
    # @return [String] The public key as hex.
    attr_reader :public_key
    # @return [String] The private key as hex.
    attr_reader :private_key
    # @return [String] The encoded seed.
    attr_reader :seed
    # @return [String] The classic address.
    attr_reader :classic_address
    # @return [String] The algorithm used ('secp256k1' or 'ed25519').
    attr_reader :algorithm

    # Initializes a new Wallet instance.
    # @param public_key [String] The public key as hex.
    # @param private_key [String] The private key as hex.
    # @param seed [String, nil] The encoded seed.
    # @param classic_address [String, nil] The classic address (optional, derived if not provided).
    def initialize(public_key, private_key, seed: nil, classic_address: nil)
      @public_key = public_key
      @private_key = private_key
      @seed = seed
      @algorithm = public_key.start_with?('ED') ? 'ed25519' : 'secp256k1'
      @key_pairs = KeyPairs::KeyPairs.new
      @classic_address = classic_address || @key_pairs.derive_address(public_key)
    end

    # Generates a new random wallet.
    # @param algorithm [String] The algorithm to use ('secp256k1' or 'ed25519').
    # @return [Wallet] A new Wallet instance.
    def self.generate(algorithm = 'secp256k1')
      kp = KeyPairs::KeyPairs.new
      seed = kp.generate_seed(nil, algorithm)
      from_seed(seed)
    end

    # Creates a wallet from a seed.
    # @param seed [String] The encoded seed.
    # @param options [Hash] Options for key derivation.
    # @return [Wallet] A new Wallet instance.
    def self.from_seed(seed, options = {})
      kp = KeyPairs::KeyPairs.new
      keys = kp.derive_key_pair(seed, options)
      new(keys[:public_key], keys[:private_key], seed: seed)
    end

    # Creates a wallet from entropy.
    # @param entropy [Array<Integer>] 16 bytes of entropy.
    # @param algorithm [String] The algorithm to use ('secp256k1' or 'ed25519').
    # @return [Wallet] A new Wallet instance.
    def self.from_entropy(entropy, algorithm = 'secp256k1')
      kp = KeyPairs::KeyPairs.new
      seed = kp.generate_seed(entropy, algorithm)
      from_seed(seed)
    end

    # Signs a message (hex string) or transaction (Hash) with the wallet's private key.
    # @param transaction [String, Hash] The message (hex string) or transaction (Hash) to sign.
    # @param multisign [Boolean] Whether to sign for a multisigned transaction.
    # @return [String, Hash] The signature (hex string) if a message was provided, 
    #   or a hash containing :tx_blob and :hash if a transaction was provided.
    def sign(transaction, multisign = false)
      algorithm = @algorithm
      # Check if message is a Hash (transaction)
      if transaction.is_a?(::Hash)
        prefix = multisign ? BinaryCodec::HASH_PREFIX[:transaction_multi_sig] : BinaryCodec::HASH_PREFIX[:transaction_sig]
        
        # 1. Prepare the transaction for signing
        tx_to_sign = transaction.dup
        if multisign
          # For multisigning, we need the SigningPubKey to be empty,
          # and we need to add the Signers field later.
          # We also need to add the Account of the signer to the signing data.
          tx_to_sign['SigningPubKey'] = ""
          # The multisign signing data MUST include the account of the signer.
        else
          tx_to_sign['SigningPubKey'] = @public_key
        end
        
        # Ensure SigningPubKey is serialized as a 0-length blob if empty
        
        signing_data = BinaryCodec.signing_data(tx_to_sign, prefix, signing_fields_only: true)
        
        if multisign
          # Append the account ID of the signer to the signing data
          account_id = AddressCodec::AddressCodec.new.decode_account_id(@classic_address)
          signing_data += account_id
        end
        
        message = bytes_to_hex(signing_data)
        
        # 2. Sign the message
        signature = @key_pairs.sign(message, @private_key, algorithm)
        
        # 3. Create the signed transaction
        signed_tx = tx_to_sign.dup
        if multisign
          # For multisign=true, xrpl.js/PHP often returns a partially signed transaction
          # or an object containing the signature for a specific signer.
          # The PHP snippet expects a tx_blob.
          # Looking at the PHP snippet, it calls $wallet->sign($tx, true).
          # In XRPL, a multisigned transaction blob is usually the transaction
          # WITH the Signers array.
          
          signer = {
            "Signer" => {
              "Account" => @classic_address,
              "SigningPubKey" => @public_key,
              "TxnSignature" => signature
            }
          }
          signed_tx['Signers'] = [signer]
          signed_tx.delete('SigningPubKey') # Should be empty/not present in multisigned tx
        else
          signed_tx['TxnSignature'] = signature
        end
        
        # 4. Serialize the signed transaction
        tx_blob = BinaryCodec.json_to_binary(signed_tx)
        
        # 5. The transaction ID: SHA512Half of 'TXN\0' and the blob
        return {
          'tx_blob' => tx_blob,
          'hash' => BinaryCodec.transaction_id(tx_blob)
        }
      end

      @key_pairs.sign(transaction, @private_key, algorithm)
    end

    # Verifies a signature for a message.
    # @param message [String] The message as a hex string.
    # @param signature [String] The signature as a hex string.
    # @return [Boolean] True if the signature is valid.
    def verify(message, signature)
      @key_pairs.verify(message, signature, @public_key)
    end

    # Verifies a signed transaction blob.
    # @param signed_transaction [String] The signed transaction blob as a hex string.
    # @return [Boolean] True if the transaction signature is valid.
    def verify_transaction(signed_transaction)
      decoded = BinaryCodec.binary_to_json(signed_transaction)
      # The signing data is the transaction without the TxnSignature field,
      # prefixed by 0x53545800 (STX\0).
      
      tx_for_signing = decoded.dup
      signature = tx_for_signing.delete('TxnSignature')
      return false unless signature

      signing_data = BinaryCodec.signing_data(tx_for_signing)
      @key_pairs.verify(bytes_to_hex(signing_data), signature, @public_key)
    end

    # Signs a payment channel claim: the promise that +amount+ drops of the
    # channel's funds may be claimed. The signature goes into a
    # PaymentChannelClaim transaction as its Signature.
    #
    # @param channel [String] the channel ID, 64 hex characters
    # @param amount [String, Integer] the amount in drops
    # @return [String] the signature as hex
    def sign_payment_channel_claim(channel, amount)
      data = BinaryCodec.signing_claim_data(channel: channel, amount: amount)
      @key_pairs.sign(bytes_to_hex(data), @private_key, @algorithm)
    end

    # Verifies a payment channel claim against this wallet's public key.
    #
    # @param channel [String] the channel ID, 64 hex characters
    # @param amount [String, Integer] the amount in drops
    # @param signature [String] the signature as hex
    # @return [Boolean] whether the claim was signed by this wallet
    def verify_payment_channel_claim(channel, amount, signature)
      self.class.verify_payment_channel_claim(channel, amount, signature, @public_key)
    end

    # Verifies a payment channel claim against any public key - the channel's
    # PublicKey, as the receiving side has it.
    #
    # @param public_key [String] the public key as hex
    # @return [Boolean] whether the claim was signed with that key
    def self.verify_payment_channel_claim(channel, amount, signature, public_key)
      data = BinaryCodec.signing_claim_data(channel: channel, amount: amount)
      KeyPairs::KeyPairs.new.verify(bytes_to_hex(data), signature, public_key)
    end

    # Signs a Batch (XLS-56) for an account with inner transactions in it:
    # the BatchSigners entry that account contributes. The outer account does
    # not need one; it signs the whole Batch with #sign once the entries are
    # in (see .combine_batch_signers).
    #
    # The Batch must be complete: Account, Sequence, Flags and the inner
    # transactions as XRPL::Client#autofill leaves them, because the
    # signature covers the inner transaction IDs.
    #
    # @param batch [Hash, XRPL::Transaction] the Batch
    # @param batch_account [String, nil] the account to sign for; by default
    #   this wallet's. Another account when this wallet is its regular key,
    #   or the account whose signer list this wallet belongs to.
    # @param multisign [Boolean, String] true to sign as one signer of
    #   batch_account's signer list, as this wallet's own account; or the
    #   signer account, when this wallet is that signer's regular key
    # @return [Hash] a copy of the Batch whose BatchSigners holds this one entry
    # @raise [ArgumentError] for anything but a Batch, or an account with no
    #   inner transaction in it
    def sign_batch(batch, batch_account: nil, multisign: false)
      batch = self.class.batch_hash(batch)
      batch_account ||= @classic_address
      unless self.class.batch_signer_accounts(batch).include?(batch_account)
        raise ArgumentError, "#{batch_account} has no inner transaction to sign for in this Batch"
      end

      entry = { 'Account' => batch_account }
      if multisign
        signer_account = multisign.is_a?(String) ? multisign : @classic_address
        data = BinaryCodec.signing_batch_data(batch, batch_account: batch_account, signer_account: signer_account)
        entry['Signers'] = [{ 'Signer' => {
          'Account' => signer_account,
          'SigningPubKey' => @public_key,
          'TxnSignature' => @key_pairs.sign(bytes_to_hex(data), @private_key, @algorithm)
        } }]
      else
        data = BinaryCodec.signing_batch_data(batch, batch_account: batch_account)
        entry['SigningPubKey'] = @public_key
        entry['TxnSignature'] = @key_pairs.sign(bytes_to_hex(data), @private_key, @algorithm)
      end

      batch.merge('BatchSigners' => [{ 'BatchSigner' => entry }])
    end

    # The accounts that sign a Batch's BatchSigners: the Account of every
    # inner transaction, or its Delegate when it has one, since the delegate
    # acts for the account. Each account once, in order of appearance. The
    # outer account is included; its entry is dropped when combining.
    #
    # @param batch [Hash, XRPL::Transaction] the Batch
    # @return [Array<String>]
    def self.batch_signer_accounts(batch)
      batch_hash(batch)['RawTransactions'].map do |wrapper|
        inner = wrapper['RawTransaction'] || {}
        inner['Delegate'] || inner['Account']
      end.compact.uniq
    end

    # Merges the copies of a Batch that each signer returned from
    # #sign_batch into one Batch carrying all BatchSigners entries, ready for
    # the outer account to sign with #sign.
    #
    # Entries are sorted by numeric AccountID, as rippled requires. The outer
    # account's entry is dropped: its signature is the outer one. Signatures
    # of the same account's signer list are merged into one entry with its
    # Signers sorted the same way; an identical entry given twice is kept once.
    #
    # @param batches [Array<Hash, String>] the signed copies, as Hashes or
    #   serialised hex
    # @return [Hash] the Batch with the combined BatchSigners
    # @raise [ArgumentError] when the copies are not of the same Batch, one
    #   carries no BatchSigners, or the outer transaction is already signed
    def self.combine_batch_signers(batches)
      batches = Array(batches).map { |b| b.is_a?(String) ? BinaryCodec.binary_to_json(b) : batch_hash(b) }
      raise ArgumentError, 'combine_batch_signers needs at least one signed Batch' if batches.empty?

      batches.each do |b|
        raise ArgumentError, 'The Batch must not be signed yet; the outer account signs last' if b['TxnSignature'] || b['Signers']
        raise ArgumentError, 'Every Batch to combine needs BatchSigners' if Array(b['BatchSigners']).empty?
      end
      unsigned = batches.map { |b| b.reject { |key, _| key == 'BatchSigners' } }
      unless unsigned.uniq.size == 1
        raise ArgumentError, 'The Batches to combine have to be the same apart from BatchSigners'
      end

      outer = batches.first['Account']
      by_account = {}
      batches.flat_map { |b| b['BatchSigners'] }.each do |wrapper|
        entry = wrapper['BatchSigner']
        account = entry['Account']
        next if account == outer

        by_account[account] = merge_batch_signer(by_account[account], entry)
      end

      entries = by_account.values.sort_by { |entry| account_sort_key(entry['Account']) }
      unsigned.first.merge('BatchSigners' => entries.map { |entry| { 'BatchSigner' => entry } })
    end

    # @api private
    def self.batch_hash(batch)
      batch = batch.to_h if !batch.is_a?(::Hash) && batch.respond_to?(:to_h)
      unless batch.is_a?(::Hash) && batch['TransactionType'] == 'Batch'
        raise ArgumentError, 'sign_batch needs a Batch transaction'
      end

      batch
    end

    # Two entries for the same account: identical ones collapse, signer-list
    # entries merge their Signers, anything else is a conflict.
    def self.merge_batch_signer(existing, entry)
      return entry if existing.nil? || existing == entry

      unless existing['Signers'] && entry['Signers']
        raise ArgumentError, "Conflicting BatchSigners entries for #{entry['Account']}"
      end

      signers = (existing['Signers'] + entry['Signers'])
                .uniq { |s| s['Signer']['Account'] }
                .sort_by { |s| account_sort_key(s['Signer']['Account']) }
      existing.merge('Signers' => signers)
    end

    def self.account_sort_key(address)
      AddressCodec::AddressCodec.new.decode_account_id(address).to_a
    end

    private_class_method :merge_batch_signer, :account_sort_key

    # Derives the X-address for this wallet.
    # @param tag [Integer, false, nil] The destination tag.
    # @param test_network [Boolean] Whether the address is for a test network.
    # @return [String] The encoded X-address.
    def get_x_address(tag: nil, test_network: false)
      address_codec = AddressCodec::AddressCodec.new
      address_codec.classic_address_to_x_address(@classic_address, tag, test_network)
    end

    # @return [String] String representation of the wallet.
    def to_s
      "Wallet(address: #{@classic_address}, public_key: #{@public_key})"
    end
  end
end
