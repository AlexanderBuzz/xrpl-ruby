# frozen_string_literal: true

require 'ed25519'

module KeyPairs
  # Ed25519 implementation for XRPL key pairs.
  module Ed25519
    # Derives a key pair from a seed.
    # @param seed [Array<Integer>] 16 bytes of seed entropy.
    # @return [Hash] A hash containing :public_key and :private_key (hex strings).
    def self.derive_key_pair(seed)
      # XRPL Ed25519 uses the SHA512 of the 16-byte seed as the 32-byte entropy for the signing key.
      seed_bytes = seed.is_a?(Array) ? seed.pack('C*') : seed
      hash = Digest::SHA512.digest(seed_bytes)[0...32]
      signing_key = ::Ed25519::SigningKey.new(hash)
      
      # Public key in XRPL is 0xED followed by 32 bytes of public key.
      public_key = [0xED].pack('C') + signing_key.verify_key.to_bytes
      
      # Private key in XRPL is 0xED followed by the 32-byte hash.
      private_key = [0xED].pack('C') + hash

      {
        public_key: public_key.unpack1('H*').upcase,
        private_key: private_key.unpack1('H*').upcase
      }
    end

    # Signs a message with a private key.
    # @param message [Array<Integer>, String] The message to sign.
    # @param private_key [String] The private key (32-byte hash as hex).
    # @return [String] The signature (hex string).
    def self.sign(message, private_key)
      msg_bytes = message.is_a?(String) ? [message].pack('H*') : message.pack('C*')
      key_bytes = [private_key].pack('H*')
      # In XRPL, Ed25519 private keys are often prefixed with 0xED (33 bytes).
      # The ed25519 gem expects 32 bytes.
      key_bytes = key_bytes[1..-1] if key_bytes.length == 33 && key_bytes[0].ord == 0xED
      signing_key = ::Ed25519::SigningKey.new(key_bytes)
      
      signature = signing_key.sign(msg_bytes)
      signature.unpack1('H*').upcase
    end

    # Verifies a signature.
    # @param message [Array<Integer>, String] The message.
    # @param signature [String] The signature (hex string).
    # @param public_key [String] The public key (33-byte hex, starts with ED).
    # @return [Boolean] True if the signature is valid.
    def self.verify(message, signature, public_key)
      msg_bytes = message.is_a?(String) ? hex_to_bin(message) : message.pack('C*')
      sig_bytes = [signature].pack('H*')
      
      # Strip the 0xED prefix from the public key
      pub_bytes = [public_key].pack('H*')
      if pub_bytes[0].ord != 0xED
        raise ArgumentError, "Invalid Ed25519 public key prefix"
      end
      
      verify_key = ::Ed25519::VerifyKey.new(pub_bytes[1..-1])
      begin
        verify_key.verify(sig_bytes, msg_bytes)
        true
      rescue ::Ed25519::VerifyError
        false
      end
    end
  end
end
