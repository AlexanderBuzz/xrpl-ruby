# frozen_string_literal: true

require 'openssl'

module KeyPairs
  # Secp256k1 implementation for XRPL key pairs.
  module Secp256k1
    # Derives a key pair from a seed.
    # @param seed [Array<Integer>] 16 bytes of seed entropy.
    # @return [Hash] A hash containing :public_key and :private_key (hex strings).
    def self.derive_key_pair(seed)
      # XRPL Secp256k1 uses a specific derivation algorithm (seed -> family seed -> sequence 0 key).
      # Seed is passed as a 16-byte array.
      private_key = derive_private_key(seed)
      public_key = derive_public_key(private_key)
      
      {
        public_key: public_key.unpack1('H*').upcase,
        private_key: private_key.unpack1('H*').upcase
      }
    end

    # Signs a message with a private key.
    # @param message [Array<Integer>, String] The message to sign.
    # @param private_key [String] The private key (hex string).
    # @return [String] The signature (hex string).
    def self.sign(message, private_key)
      msg_hash = message.is_a?(String) ? [message].pack('H*') : message.pack('C*')
      
      # Use the dsa_sign_asn1 method directly on a PKey::EC object.
      # In OpenSSL 3.0, setting private_key might be blocked if not done carefully.
      # We use a fresh object and set the key.
      ec = OpenSSL::PKey::EC.new('secp256k1')
      begin
        # Use send to bypass potential visibility or immutability checks if any,
        # but usually private_key= is public.
        ec.private_key = OpenSSL::BN.new(private_key, 16)
        ec.public_key = ec.group.generator.mul(ec.private_key)
        
        signature = ec.dsa_sign_asn1(msg_hash)
        signature.unpack1('H*').upcase
      rescue OpenSSL::PKey::PKeyError => e
        # If OpenSSL 3.0 is too strict, we might be unable to sign without a dedicated gem.
        # However, for the sake of completion, we'll try a fallback if it exists.
        raise "Secp256k1 signing failed: #{e.message}. This might be due to OpenSSL 3.0 immutability."
      end
    end

    # Verifies a signature.
    # @param message [Array<Integer>, String] The message.
    # @param signature [String] The signature (hex string).
    # @param public_key [String] The public key (hex string).
    # @return [Boolean] True if the signature is valid.
    def self.verify(message, signature, public_key)
      msg_hash = message.is_a?(String) ? [message].pack('H*') : message.pack('C*')
      sig_bytes = [signature].pack('H*')
      
      ec = OpenSSL::PKey::EC.new('secp256k1')
      ec.public_key = OpenSSL::PKey::EC::Point.new(ec.group, OpenSSL::BN.new(public_key, 16))
      
      ec.dsa_verify_asn1(msg_hash, sig_bytes)
    end

    private

    # Derives the 32-byte private key from the 16-byte seed.
    # This follows the Ripple seed derivation algorithm.
    def self.derive_private_key(seed, account_index = 0)
      ec_key = OpenSSL::PKey::EC.new('secp256k1')
      order = ec_key.group.order
      
      # 1. Derive root private key from seed
      root_private_key = derive_scalar(seed)
      
      # 2. Derive root public key from root private key
      root_public_key = derive_root_public_key(root_private_key)
      
      # 3. Derive child scalar from root public key and account_index
      child_scalar = derive_scalar(root_public_key, account_index)
      
      # 4. child_private_key = (root_private_key + child_scalar) % order
      child_private_key = (OpenSSL::BN.new(root_private_key, 16) + OpenSSL::BN.new(child_scalar, 16)) % order
      child_private_key.to_s(16).rjust(64, '0')
    end

    def self.derive_scalar(seed, sequence = nil)
      seed_bytes = seed.is_a?(Array) ? seed.pack('C*') : seed
      ec_key = OpenSSL::PKey::EC.new('secp256k1')
      order = ec_key.group.order
      loop_count = 0
      loop do
        data = sequence ? seed_bytes + [sequence].pack('N') : seed_bytes
        data += [loop_count].pack('N')
        hash = Digest::SHA512.digest(data)[0...32]
        scalar = OpenSSL::BN.new(hash.unpack1('H*'), 16)
        
        if scalar > 0 && scalar < order
          return scalar.to_s(16).rjust(64, '0')
        end
        loop_count += 1
        raise "Too many loops" if loop_count > 100
      end
    end

    def self.derive_root_public_key(private_key_hex)
      group = OpenSSL::PKey::EC::Group.new('secp256k1')
      key_bn = OpenSSL::BN.new(private_key_hex, 16)
      pub_key_point = group.generator.mul(key_bn)
      pub_key_point.to_octet_string(:compressed)
    end

    def self.derive_public_key(private_key_hex)
      derive_root_public_key(private_key_hex)
    end
  end
end
