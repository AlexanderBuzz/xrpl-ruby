require 'address-codec/address_codec'
require 'address-codec/xrp_codec'

module BinaryCodec
    class AccountId < Hash160

        # Create a single instance of AddressCodec for use in static functions
        @address_codec = AddressCodec::AddressCodec.new

        attr_reader :bytes

        @width = 20

        def initialize(bytes = nil)
            super(bytes || Array.new(20, 0))
        end

        #def self.address_codec
        #    @address_codec ||= AddressCodec::AddressCodec.new
        #end

        # Defines how to construct an AccountID
        #
        # @param value [AccountID, String] Either an existing AccountID, a hex string, or a base58 r-Address
        # @return [AccountID] An AccountID object
        def self.from(value)
            if value.is_a?(AccountId)
                return value
            end

            if value.is_a?(String)
                return AccountId.new if value.empty?

                if valid_hex?(value)
                    return AccountId.new(hex_to_bytes(value))
                else
                    return from_base58(value)
                end
            end

            raise 'Cannot construct AccountID from the value provided'
        end

        # Defines how to build an AccountID from a base58 r-Address
        #
        # @param value [String] A base58 r-Address
        # @return [AccountID] An AccountID object
        def self.from_base58(value)
            if @address_codec.valid_x_address?(value)
                classic = @address_codec.x_address_to_classic_address(value)

                if classic[:tag] != false
                    raise 'Only allowed to have tag on Account or Destination'
                end

                value = classic[:classic_address]
            end

            AccountId.new(@address_codec.decode_account_id(value))
        end

        # Overload of to_json
        #
        # @return [String] The base58 string for this AccountID
        def to_json
            to_base58
        end

        # Defines how to encode AccountID into a base58 address
        #
        # @return [String] The base58 string defined by this.bytes
        def to_base58
            address_codec = AddressCodec::AddressCodec.new
            address_codec.encode_account_id(@bytes)
        end

    end

end