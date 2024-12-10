# frozen_string_literal: true
module AddressCodec

  class AddressCodec < XrpCodec

    PREFIX_BYTES = {
      main: [0x05, 0x44],
      test: [0x04, 0x93]
    }

    MAX_32_BIT_UNSIGNED_INT = 4294967295

    def classic_address_to_x_address(classic_address, tag, test)
      account_id = decode_account_id(classic_address)
      encode_x_address(account_id, tag, test)
    end

    def encode_x_address(account_id, tag, test)
      if account_id.length != 20
        # RIPEMD160 ist 160 Bits = 20 Bytes
        raise 'Account ID must be 20 bytes'
      end
      if tag != false && tag > MAX_32_BIT_UNSIGNED_INT
        raise 'Invalid tag'
      end
      the_tag = tag || 0
      flag = tag == false || tag.nil? ? 0 : 1

      bytes = concat_args(
        test ? PREFIX_BYTES[:test] : PREFIX_BYTES[:main],
        account_id,
        [
          flag,
          the_tag & 0xff,
          (the_tag >> 8) & 0xff,
          (the_tag >> 16) & 0xff,
          (the_tag >> 24) & 0xff,
          0,
          0,
          0,
          0
        ]
      )

      encode_checked(bytes)
    end

  end

end