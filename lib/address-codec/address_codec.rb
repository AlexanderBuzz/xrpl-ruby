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
        # RIPEMD160 -> 160 Bits = 20 Bytes
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

    def x_address_to_classic_address(x_address)
      decoded = decode_x_address(x_address)
      account_id = decoded[:account_id]
      tag = decoded[:tag]
      test = decoded[:test]
      classic_address = encode_account_id(account_id)
      {
        classic_address: classic_address,
        tag: tag,
        test: test
      }
    end

    def decode_x_address(x_address)
      decoded = decode_checked(x_address)
      test = is_uint8_array_for_test_address(decoded)
      account_id = decoded[2, 20]
      tag = tag_from_uint8_array(decoded)
      {
        account_id: account_id,
        tag: tag,
        test: test
      }
    end

    def valid_x_address?(x_address)
      begin
        decode_x_address(x_address)
      rescue
        return false
      end
      true
    end

    private

    def is_uint8_array_for_test_address(buf)
      decoded_prefix = buf[0, 2]
      if decoded_prefix == PREFIX_BYTES[:main]
        return false
      end
      if decoded_prefix == PREFIX_BYTES[:test]
        return true
      end

      raise 'Invalid X-address: bad prefix'
    end

    def tag_from_uint8_array(bytes)
      flag = bytes[22]
      if flag >= 2
        # Keine Unterstützung für 64-Bit-Tags zu diesem Zeitpunkt
        raise 'Unsupported X-address'
      end
      if flag == 1
        # Little-endian zu Big-endian
        return bytes[23] + bytes[24] * 0x100 + bytes[25] * 0x10000 + bytes[26] * 0x1000000
      end
      if flag != 0
        raise 'flag must be zero to indicate no tag'
      end
      if '0000000000000000' !=  bytes_to_hex(bytes[23, 8])
        raise 'remaining bytes must be zero'
      end
      false
    end

  end

end