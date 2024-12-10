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
        expectedLength: 16,
        versions: type == 'ed25519' ? ED25519_SEED : [FAMILY_SEED]
      }

      # prefixes entropy with version bytes
      encode(entropy, opts)
    end

    def decode_seed(seed, opts = {
          versionTypes: ['ed25519', 'secp256k1'],
          versions: [ED25519_SEED, FAMILY_SEED],
          expectedLength: 16
        })
      decode(seed, opts)
    end

  end

end