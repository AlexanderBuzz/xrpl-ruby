# frozen_string_literal: true

require 'bigdecimal'
require 'bigdecimal/util'

require_relative '../utilities'

module BinaryCodec
  class Amount < SerializedType

    DEFAULT_AMOUNT_HEX = "4000000000000000".freeze
    ZERO_CURRENCY_AMOUNT_HEX = "8000000000000000".freeze
    NATIVE_AMOUNT_BYTE_LENGTH = 8
    CURRENCY_AMOUNT_BYTE_LENGTH = 48
    MAX_IOU_PRECISION = 16
    MIN_IOU_EXPONENT = -96
    MAX_IOU_EXPONENT = 80

    MAX_DROPS = BigDecimal("1e17")
    MIN_XRP = BigDecimal("1e-6")

    def initialize(bytes = nil)
      if bytes.nil?
        bytes = hex_to_bytes(DEFAULT_AMOUNT_HEX)
      end

      @bytes = bytes
    end

    # Construct an amount from an IOU, MPT, or string amount
    #
    # @param value [Amount, Hash, String] representing the amount
    # @return [Amount] an Amount object
    def self.from(value)
      return value if value.is_a?(Amount)

      amount = Array.new(8, 0) # Equivalent to a Uint8Array of 8 zeros

      if value.is_a?(String)
        Amount.assert_xrp_is_valid(value)

        number = value.to_i # Use to_i for equivalent BigInt handling

        int_buf = [Array.new(4, 0), Array.new(4, 0)]
        BinaryCodec.write_uint32be(int_buf[0], (number >> 32) & 0xFFFFFFFF, 0)
        BinaryCodec.write_uint32be(int_buf[1], number & 0xFFFFFFFF, 0)

        amount = int_buf.flatten

        amount[0] |= 0x40

        return Amount.new(amount)
      end

      if is_amount_object_iou?(value)
        number = BigDecimal(value[:value])
        self.assert_iou_is_valid(number)

        if number.zero?
          amount[0] |= 0x80
        else
          scale = number.frac.to_s('F').split('.').last.size
          unscaled_value = (number * (10**scale)).to_i
          int_string = unscaled_value.abs.to_s.ljust(16, '0')
          num = int_string.to_i

          int_buf = [Array.new(4, 0), Array.new(4, 0)]
          BinaryCodec.write_uint32be(int_buf[0], (num >> 32) & 0xFFFFFFFF)
          BinaryCodec.write_uint32be(int_buf[1], num & 0xFFFFFFFF)

          amount = int_buf.flatten

          amount[0] |= 0x80

          if number > 0
            amount[0] |= 0x40
          end

          exponent = number.exponent - 16
          exponent_byte = 97 + exponent
          amount[0] |= exponent_byte >> 2
          amount[1] |= (exponent_byte & 0x03) << 6
        end

        currency = Currency.from(value[:currency]).to_bytes
        issuer = AccountId.from(value[:issuer]).to_bytes

        return Amount.new(amount + currency + issuer)
      end

    end

    # Read an amount from a BinaryParser
    #
    # @param parser [BinaryParser] The BinaryParser to read the Amount from
    # @return [Amount] An Amount object
    def self.from_parser(parser)
      is_iou = parser.peek & 0x80 != 0
      return Amount.new(parser.read(48)) if is_iou

      # The amount can be either MPT or XRP at this point
      is_mpt = parser.peek & 0x20 != 0
      num_bytes = is_mpt ? 33 : 8
      Amount.new(parser.read(num_bytes))
    end

    # The JSON representation of this Amount
    #
    # @return [Hash, String] The JSON interpretation of this.bytes
    def to_json
      if is_native?
        bytes = @bytes.dup # Duplicate the bytes to avoid mutation
        is_positive = (bytes[0] & 0x40) != 0
        sign = is_positive ? '' : '-'
        bytes[0] &= 0x3f

        msb = BinaryCodec.read_uint32be(bytes[0, 4])
        lsb = BinaryCodec.read_uint32be(bytes[4, 4])
        num = (msb << 32) | lsb

        return "#{sign}#{num}"
      end

      if is_iou?
        parser = BinaryParser.new(to_s)
        mantissa = parser.read(8)
        currency = Currency.from_parser(parser)
        issuer = AccountId.from_parser(parser)

        b1 = mantissa[0]
        b2 = mantissa[1]

        is_positive = (b1 & 0x40) != 0
        sign = is_positive ? '' : '-'
        exponent = ((b1 & 0x3f) << 2) + ((b2 & 0xff) >> 6) - 97

        mantissa[0] = 0
        mantissa[1] &= 0x3f
        value = BigDecimal("#{sign}0x#{bytes_to_hex(mantissa)}") * BigDecimal("1e#{exponent}")
        self.assert_iou_is_valid(value)

        return {
          value: value.to_s,
          currency: currency.to_json,
          issuer: issuer.to_json
        }.to_s
      end

      if is_mpt?
        parser = BinaryParser.new(to_s)
        leading_byte = parser.read(1)
        amount = parser.read(8)
        mpt_id = Hash192.from_parser(parser)

        is_positive = (leading_byte[0] & 0x40) != 0
        sign = is_positive ? '' : '-'

        msb = read_uint32be(amount[0, 4])
        lsb = read_uint32be(amount[4, 4])
        num = (msb << 32) | lsb

        return {
          value: "#{sign}#{num}",
          mpt_issuance_id: mpt_id.to_s
        }.to_s
      end

      raise 'Invalid amount to construct JSON'
    end

    private

    # Type guard for AmountObjectIOU
    def self.is_amount_object_iou?(arg)
      keys = arg.transform_keys(&:to_s).keys.sort

      keys.length == 3 &&
        keys[0] == 'currency' &&
        keys[1] == 'issuer' &&
        keys[2] == 'value'
    end

    # Type guard for AmountObjectMPT
    def self.is_amount_object_mpt?(arg)
      keys = arg.keys.sort

      keys.length == 2 &&
        keys[0] == 'mpt_issuance_id' &&
        keys[1] == 'value'
    end

    # Validate XRP amount
    #
    # @param amount [String] representing XRP amount
    # @return [void], but raises an exception if the amount is invalid
    def self.assert_xrp_is_valid(amount)
      if amount.include?('.')
        raise "#{amount} is an illegal amount"
      end

      decimal = BigDecimal(amount)
      unless decimal.zero?
        if decimal < MIN_XRP || decimal > MAX_DROPS
          raise "#{amount} is an illegal amount"
        end
      end
    end

    # Validate IOU.value amount
    #
    # @param decimal [BigDecimal] object representing IOU.value
    # @raise [ArgumentError] if the amount is invalid
    def self.assert_iou_is_valid(decimal)
      return if decimal.zero?

      p = decimal.precision
      e = (decimal.exponent || 0) - 15

      if p > MAX_IOU_PRECISION || e > MAX_IOU_EXPONENT || e < MIN_IOU_EXPONENT
        raise ArgumentError, 'Decimal precision out of range'
      end

      verify_no_decimal(decimal)
    end

    # Validate MPT.value amount
    #
    # @param amount [String] representing MPT.value
    # @return [void], but raises an exception if the amount is invalid
    def self.assert_mpt_is_valid(amount)
      if amount.include?('.')
        raise "#{amount} is an illegal amount"
      end

      decimal = BigDecimal(amount)
      unless decimal.zero?
        if decimal < BigDecimal("0")
          raise "#{amount} is an illegal amount"
        end

        if (amount.to_i & mpt_mask) != 0
          raise "#{amount} is an illegal amount"
        end
      end
    end

    # Ensure that the value, after being multiplied by the exponent, does not
    # contain a decimal. This function is typically used to validate numbers
    # that need to be represented as precise integers after scaling, such as
    # amounts in financial transactions.
    #
    # @param decimal [BigDecimal] A BigDecimal object
    # @raise [ArgumentError] if the value contains a decimal
    # @return [String] The decimal converted to a string without a decimal point
    def self.verify_no_decimal(decimal)
      exponent = -((decimal.exponent || 0) - 16)
      scaled_decimal = decimal * 10 ** exponent

        raise ArgumentError, 'Decimal place found in int_string' unless scaled_decimal.frac == 0
    end

    # Check if this amount is in units of Native Currency (XRP)
    #
    # @return [Boolean] true if Native (XRP)
    def is_native?
      (self.bytes[0] & 0x80).zero? && (self.bytes[0] & 0x20).zero?
    end

    # Check if this amount is in units of MPT
    #
    # @return [Boolean] true if MPT
    def is_mpt?
      (self.bytes[0] & 0x80).zero? && (self.bytes[0] & 0x20) != 0
    end

    # Check if this amount is in units of IOU
    #
    # @return [Boolean] true if IOU
    def is_iou?
      (self.bytes[0] & 0x80) != 0
    end

  end
end