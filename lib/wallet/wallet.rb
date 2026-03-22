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
        
        # 5. Generate the hash (transaction ID)
        # For transactions, the hash is SHA512Half of the serialized transaction with a prefix
        hash_prefix = [0x54, 0x58, 0x4E, 0x00].pack('C*') # 'TXN\0'
        hash = Digest::SHA512.digest(hash_prefix + [tx_blob].pack('H*'))[0...32].unpack1('H*').upcase
        
        return {
          'tx_blob' => tx_blob,
          'hash' => hash
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
