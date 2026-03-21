# frozen_string_literal: true

module AddressCodec

  class XrpCodec < Codec

    # base58 encodings: https://xrpl.org/base58-encodings.html
    ACCOUNT_ID = 0            # Account address (20 bytes)
    ACCOUNT_PUBLIC_KEY = 0x23 # Account public key (33 bytes)
    FAMILY_SEED = 0x21        # 33; Seed value (for secret keys) (16 bytes)
    NODE_PUBLIC = 0x1c        # 28; Validation public key (33 bytes)
    ED25519_SEED = [0x01, 0xe1, 0x4b].freeze # [1, 225, 75]

    # Encodes entropy into a seed string.
    # @param entropy [Array<Integer>] 16 bytes of entropy.
    # @param type [String, nil] The seed type ('ed25519' or 'secp256k1').
    # @return [String] The encoded seed string.
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

    # Decodes a seed string into its underlying bytes and type.
    # @param seed [String] The seed string to decode.
    # @param opts [Hash] Options for decoding (e.g., :versions, :version_types, :expected_length).
    # @return [Hash] The decoded data including version, bytes, and type.
    def decode_seed(seed, opts = {
          version_types: ['ed25519', 'secp256k1'],
          versions: [ED25519_SEED, FAMILY_SEED],
          expected_length: 16
        })
      decode(seed, opts)
    end

    # Encodes a byte array into an account ID string.
    # @param bytes [Array<Integer>] 20 bytes for the account ID.
    # @return [String] The encoded account ID string.
    def encode_account_id(bytes)
      opts = { versions: [ACCOUNT_ID], expected_length: 20 }
      encode(bytes, opts)
    end

    # Decodes an account ID string into its underlying bytes.
    # @param account_id [String] The account ID string to decode.
    # @return [Array<Integer>] The decoded bytes.
    def decode_account_id(account_id)
      opts = { versions: [ACCOUNT_ID], expected_length: 20 }
      decode(account_id, opts)[:bytes]
    end

    # Decodes a node public key string into its underlying bytes.
    # @param base58string [String] The node public key string to decode.
    # @return [Array<Integer>] The decoded bytes.
    def decode_node_public(base58string)
      opts = { versions: [NODE_PUBLIC], expected_length: 33 }
      decode(base58string, opts)[:bytes]
    end

    # Encodes a byte array into a node public key string.
    # @param bytes [Array<Integer>] 33 bytes for the node public key.
    # @return [String] The encoded node public key string.
    def encode_node_public(bytes)
      opts = { versions: [NODE_PUBLIC], expected_length: 33 }
      encode(bytes, opts)
    end

    # Encodes a byte array into an account public key string.
    # @param bytes [Array<Integer>] 33 bytes for the account public key.
    # @return [String] The encoded account public key string.
    def encode_account_public(bytes)
      opts = { versions: [ACCOUNT_PUBLIC_KEY], expected_length: 33 }
      encode(bytes, opts)
    end

    # Decodes an account public key string into its underlying bytes.
    # @param base58string [String] The account public key string to decode.
    # @return [Array<Integer>] The decoded bytes.
    def decode_account_public(base58string)
      opts = { versions: [ACCOUNT_PUBLIC_KEY], expected_length: 33 }
      decode(base58string, opts)[:bytes]
    end

    # Checks if a string is a valid classic XRPL address.
    # @param address [String] The address string to check.
    # @return [Boolean] True if the address is valid, false otherwise.
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