# frozen_string_literal: true

require 'openssl'
require 'ecdsa'
require 'digest'

module KeyPairs
  # Secp256k1 implementation for XRPL key pairs.
  module Secp256k1
    GROUP = ECDSA::Group::Secp256k1

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
        private_key: private_key.upcase.rjust(66, '00')
      }
    end

    # Signs a message with a private key.
    # @param message [Array<Integer>, String] The message to sign (hex string or byte array).
    # @param private_key [String] The private key (hex string).
    # @return [String] The signature (hex string).
    def self.sign(message, private_key)
      msg_hash = message.is_a?(String) ? [message].pack('H*') : message.pack('C*')
      
      # If message is not already 32 bytes, we hash it.
      # This is a bit of a heuristic. XRPL signs the SHA512Half hash of the serialized transaction.
      if msg_hash.length != 32
        msg_hash = Digest::SHA512.digest(msg_hash)[0...32]
      end

      priv_key_bn = private_key.to_i(16)
      k = generate_k(priv_key_bn, msg_hash)
      signature = ECDSA.sign(GROUP, priv_key_bn, msg_hash, k)
      
      # XRPL requires "canonical" signatures: S <= order / 2
      if signature.s > (GROUP.order / 2)
        signature = ECDSA::Signature.new(signature.r, GROUP.order - signature.s)
      end
      
      ECDSA::Format::SignatureDerString.encode(signature).unpack1('H*').upcase
    end

    # Deterministic k generation (RFC 6979)
    def self.generate_k(private_key_bn, message_hash)
      q = GROUP.order
      q_len = q.bit_length
      holeren = (q_len + 7) / 8
      
      # Step b
      v = "\x01" * holeren
      # Step c
      k = "\x00" * holeren
      
      # bits2octets(x)
      x_bytes = [private_key_bn.to_s(16).rjust(holeren * 2, '0')].pack('H*')
      # bits2octets(bits2int(h1))
      h1_val = message_hash.unpack1('H*').to_i(16)
      if h1_val >= q
        h1_val %= q
      end
      h1 = [h1_val.to_s(16).rjust(holeren * 2, '0')].pack('H*')

      # Step d
      k = OpenSSL::HMAC.digest('sha256', k, v + "\x00" + x_bytes + h1)
      # Step e
      v = OpenSSL::HMAC.digest('sha256', k, v)
      # Step f
      k = OpenSSL::HMAC.digest('sha256', k, v + "\x01" + x_bytes + h1)
      # Step g
      v = OpenSSL::HMAC.digest('sha256', k, v)
      
      # Step h
      loop do
        t = ""
        while t.length < holeren
          v = OpenSSL::HMAC.digest('sha256', k, v)
          t += v
        end
        
        k_val = t[0...holeren].unpack1('H*').to_i(16)
        # bits2int(T)
        if q_len < 8 * holeren
          k_val >>= (8 * holeren - q_len)
        end

        return k_val if k_val > 0 && k_val < q
        
        k = OpenSSL::HMAC.digest('sha256', k, v + "\x00")
        v = OpenSSL::HMAC.digest('sha256', k, v)
      end
    end

    # Verifies a signature.
    # @param message [Array<Integer>, String] The message (hex string or byte array).
    # @param signature [String] The signature (hex string).
    # @param public_key [String] The public key (hex string).
    # @return [Boolean] True if the signature is valid.
    def self.verify(message, signature, public_key)
      msg_hash = message.is_a?(String) ? [message].pack('H*') : message.pack('C*')
      
      # If message is not already 32 bytes, we hash it.
      if msg_hash.length != 32
        msg_hash = Digest::SHA512.digest(msg_hash)[0...32]
      end

      sig_bytes = [signature].pack('H*')
      
      point = ECDSA::Format::PointOctetString.decode([public_key].pack('H*'), GROUP)
      sig = ECDSA::Format::SignatureDerString.decode(sig_bytes)
      
      ECDSA.valid_signature?(point, msg_hash, sig)
    end

    private

    # Derives the 32-byte private key from the 16-byte seed.
    # This follows the Ripple seed derivation algorithm.
    def self.derive_private_key(seed, account_index = 0)
      # 1. Derive root private key from seed
      root_private_key = derive_scalar(seed)
      
      # 2. Derive root public key from root private key
      root_public_key = derive_root_public_key(root_private_key)
      
      # 3. Derive child scalar from root public key and account_index
      child_scalar = derive_scalar(root_public_key, account_index)
      
      # 4. child_private_key = (root_private_key + child_scalar) % order
      child_private_key = (root_private_key.to_i(16) + child_scalar.to_i(16)) % GROUP.order
      child_private_key.to_s(16).rjust(64, '0')
    end

    def self.derive_scalar(seed, sequence = nil)
      seed_bytes = seed.is_a?(Array) ? seed.pack('C*') : seed
      loop_count = 0
      loop do
        data = sequence ? seed_bytes + [sequence].pack('N') : seed_bytes
        data += [loop_count].pack('N')
        hash = Digest::SHA512.digest(data)[0...32]
        scalar = hash.unpack1('H*').to_i(16)
        
        if scalar > 0 && scalar < GROUP.order
          return scalar.to_s(16).rjust(64, '0')
        end
        loop_count += 1
        raise "Too many loops" if loop_count > 100
      end
    end

    def self.derive_root_public_key(private_key_hex)
      key_bn = private_key_hex.to_i(16)
      pub_key_point = GROUP.generator.multiply_by_scalar(key_bn)
      ECDSA::Format::PointOctetString.encode(pub_key_point, compression: true)
    end

    def self.derive_public_key(private_key_hex)
      derive_root_public_key(private_key_hex)
    end
  end
end
