# frozen_string_literal: true

module BinaryCodec
    class AccountId < Hash160
        @width = 20

        def initialize(bytes = nil)
            super(bytes)
        end

        def self.from(value)
            return value if value.is_a?(AccountId)

            if value.is_a?(String)
                return new if value.empty?

                if valid_hex?(value)
                    return new(hex_to_bytes(value))
                else
                    return from_base58(value)
                end
            end

            raise 'Cannot construct AccountID from the value provided'
        end

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
            to_base58
        end

        def to_base58
            address_codec = AddressCodec::AddressCodec.new
            address_codec.encode_account_id(@bytes)
        end
    end

end