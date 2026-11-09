# frozen_string_literal: true

module BinaryCodec
    # An account field can be unset, which is not the zero account: empty on the
    # wire instead of 20 zero bytes, and '' in JSON instead of
    # rrrrrrrrrrrrrrrrrrrrrhoLvTp. This follows STAccount in rippled, which keeps
    # 20 zero bytes and a flag, so a value in a fixed width position, such as the
    # issuer of an Amount, stays 20 bytes long.
    class AccountId < Hash160
        @width = 20

        def initialize(bytes = nil, unset: false)
            super(bytes)
            @unset = unset
        end

        # Creates an unset account field.
        # @return [AccountId] The created instance.
        def self.unset
            new(unset: true)
        end

        # Creates an AccountId from a parser.
        # @param parser [BinaryParser] The parser to read from.
        # @param hint [Integer, nil] The length of the field, nil at a fixed width position.
        # @return [AccountId] The created instance.
        def self.from_parser(parser, hint = nil)
            return unset if hint == 0

            super
        end

        # Whether this is an unset field rather than an account, the zero account
        # included. The serializer writes such a field with length zero.
        # @return [Boolean]
        def unset?
            @unset
        end

        # Creates a new AccountId instance from a value.
        # @param value [AccountId, String] The value to convert (hex or base58 address).
        # @return [AccountId] The created instance.
        def self.from(value)
            return value if value.is_a?(AccountId)

            if value.is_a?(String)
                return unset if value.empty?

                if valid_hex?(value)
                    return new(hex_to_bytes(value))
                else
                    return from_base58(value)
                end
            end

            raise 'Cannot construct AccountID from the value provided'
        end

        # Creates an AccountId instance from a base58 address.
        # @param value [String] The classic or X-address.
        # @return [AccountId] The created instance.
        def self.from_base58(value)
            address_codec = AddressCodec::AddressCodec.new
            if address_codec.valid_x_address?(value)
                classic = address_codec.x_address_to_classic_address(value)

                if classic[:tag] != false
                    raise 'Only allowed to have tag on Account or Destination'
                end

                value = classic[:classic_address]
            end

            new(address_codec.decode_account_id(value))
        end

        def to_json(_definitions = nil, _field_name = nil)
            unset? ? '' : to_base58
        end

        # Returns the base58 representation of the account ID.
        # @return [String] The base58 address.
        def to_base58
            address_codec = AddressCodec::AddressCodec.new
            address_codec.encode_account_id(@bytes)
        end
    end

end