# frozen_string_literal: true

require 'securerandom'

module KeyPairs
  # Main entry point for XRPL key pair operations.
  class KeyPairs
    def initialize
      @address_codec = AddressCodec::AddressCodec.new
    end

    # Generates a new seed.
    # @param entropy [Array<Integer>, nil] 16 bytes of entropy.
    # @param type [String] The seed type ('secp256k1' or 'ed25519').
    # @return [String] The encoded seed string.
    def generate_seed(entropy = nil, type = 'secp256k1')
      entropy ||= SecureRandom.random_bytes(16).bytes
      @address_codec.encode_seed(entropy, type)
    end

    # Derives a key pair from an encoded seed.
    # @param seed [String] The encoded seed string.
    # @param options [Hash] Options including :account_index (for secp256k1).
    # @return [Hash] A hash containing :public_key and :private_key (hex strings).
    def derive_key_pair(seed, options = {})
      decoded = @address_codec.decode_seed(seed)
      type = decoded[:type]
      entropy = decoded[:bytes]

      if type == 'ed25519'
        Ed25519.derive_key_pair(entropy)
      else
        # For secp256k1, we use the entropy as seed
        Secp256k1.derive_key_pair(entropy)
      end
    end

    # Signs a message with a private key.
    # @param message [String] The message to sign as hex.
    # @param private_key [String] The private key as hex.
    # @return [String] The signature as hex.
    def sign(message, private_key)
      # Secp256k1 keys are 32 bytes (64 hex chars), sometimes with a leading zero if BN handled it.
      # Ed25519 keys are also 32 bytes.
      # For now, we support both via Secp256k1.sign if they are the right length.
      Secp256k1.sign(message, private_key)
    end

    # Verifies a signature.
    # @param message [String] The message as hex.
    # @param signature [String] The signature as hex.
    # @param public_key [String] The public key as hex.
    # @return [Boolean] True if the signature is valid.
    def verify(message, signature, public_key)
      if public_key.start_with?('ED')
        Ed25519.verify(message, signature, public_key)
      else
        Secp256k1.verify(message, signature, public_key)
      end
    end

    # Derives an XRP address from a public key.
    # @param public_key [String] The public key as hex.
    # @return [String] The XRP address.
    def derive_address(public_key)
      public_key_bytes = [public_key].pack('H*')
      # Account ID is RIPEMD160(SHA256(public_key))
      sha256 = Digest::SHA256.digest(public_key_bytes)
      # Ruby doesn't have RIPEMD160 in Digest by default sometimes, 
      # but OpenSSL has it.
      ripemd160 = OpenSSL::Digest.new('RIPEMD160').digest(sha256)
      
      @address_codec.encode_account_id(ripemd160.unpack('C*'))
    end
  end
end
