# frozen_string_literal: true

require_relative "../core/core"

module AddressCodec

  class XrpCodec < Codec

    # base58 encodings: https://xrpl.org/base58-encodings.html
    ACCOUNT_ID = 0            # Account address (20 bytes)
    ACCOUNT_PUBLIC_KEY = 0x23 # Account public key (33 bytes)
    FAMILY_SEED = 0x21        # 33; Seed value (for secret keys) (16 bytes)
    NODE_PUBLIC = 0x1c        # 28; Validation public key (33 bytes)
    ED25519_SEED = [0x01, 0xe1, 0x4b].freeze # [1, 225, 75]

    def encode_seed(entropy, type = nil)
      unless check_byte_length(entropy, 16)
        raise 'entropy must have length 16'
      end

      opts = {
        expected_length: 16,
        versions: type == 'ed25519' ? ED25519_SEED : [FAMILY_SEED]
      }

      # prefixes entropy with version bytes
      encode(entropy, opts)
    end

    def decode_seed(seed, opts = {
          version_types: ['ed25519', 'secp256k1'],
          versions: [ED25519_SEED, FAMILY_SEED],
          expected_length: 16
        })
      decode(seed, opts)
    end

    def encode_account_id(bytes)
      opts = { versions: [ACCOUNT_ID], expected_length: 20 }
      encode(bytes, opts)
    end

    def decode_account_id(account_id)
      opts = { versions: [ACCOUNT_ID], expected_length: 20 }
      decode(account_id, opts)[:bytes]
    end

    def decode_node_public(base58string)
      opts = { versions: [NODE_PUBLIC], expected_length: 33 }
      decode(base58string, opts)[:bytes]
    end

    def encode_node_public(bytes)
      opts = { versions: [NODE_PUBLIC], expected_length: 33 }
      encode(bytes, opts)
    end

    def encode_account_public(bytes)
      opts = { versions: [ACCOUNT_PUBLIC_KEY], expected_length: 33 }
      encode(bytes, opts)
    end

    def decode_account_public(base58string)
      opts = { versions: [ACCOUNT_PUBLIC_KEY], expected_length: 33 }
      decode(base58string, opts)[:bytes]
    end

    def valid_classic_address?(address)
      begin
        decode_account_id(address)
      rescue
        return false
      end
      true
    end

  end

end