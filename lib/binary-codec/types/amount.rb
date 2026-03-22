# frozen_string_literal: true

require 'bigdecimal'
require 'bigdecimal/util'

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
    MIN_XRP_DROPS = 1
    MAX_XRP_DROPS = 10**17

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
    # Creates a new Amount instance from a value.
    # @param value [Amount, String, Hash, Integer] The value to convert.
    # @return [Amount] The created instance.
    def self.from(value)
      return value if value.is_a?(Amount)

      if value.is_a?(String)
        Amount.assert_xrp_is_valid(value)
        number = value.to_i
        amount_bytes = int_to_bytes(number, 8)
        amount_bytes[0] |= 0x40
        return Amount.new(amount_bytes)
      end

      if value.respond_to?(:key?)
        val = value[:value] || value['value']
        cur = value[:currency] || value['currency']
        iss = value[:issuer] || value['issuer']

        if val && cur && iss
          number = BigDecimal(val.to_s)
          
          if number.precision > MAX_IOU_PRECISION
            raise ArgumentError, 'Decimal precision out of range'
          end

          currency_inst = Currency.from(cur)
          issuer_inst = AccountId.from(iss)

          if number.zero?
            iou_bytes = [0x80, 0, 0, 0, 0, 0, 0, 0]
            return Amount.new(iou_bytes + currency_inst.to_bytes + issuer_inst.to_bytes)
          end

          is_positive = number >= 0
          abs_value = number.abs
          
          exponent = (Math.log10(abs_value.to_f).floor) - 15
          mantissa = (abs_value / (BigDecimal(10)**exponent)).to_i

          while mantissa < 1000000000000000
            mantissa *= 10
            exponent -= 1
          end
          while mantissa > 9999999999999999
            mantissa /= 10
            exponent += 1
          end

          exponent_byte = exponent + 97
          b1 = (is_positive ? 0x40 : 0) | 0x80 | (exponent_byte >> 2)
          b2 = ((exponent_byte & 0x03) << 6) | (mantissa >> 48)

          iou_bytes = [
            b1, b2,
            (mantissa >> 40) & 0xff,
            (mantissa >> 32) & 0xff,
            (mantissa >> 24) & 0xff,
            (mantissa >> 16) & 0xff,
            (mantissa >> 8) & 0xff,
            mantissa & 0xff
          ]
          return Amount.new(iou_bytes + currency_inst.to_bytes + issuer_inst.to_bytes)
        end
      end

      if value.is_a?(Integer)
        Amount.assert_xrp_is_valid(value.to_s)
        amount_bytes = int_to_bytes(value, 8)
        amount_bytes[0] |= 0x40
        return Amount.new(amount_bytes)
      end

      raise ArgumentError, "Cannot construct Amount from the value given"
    end

    # Read an amount from a BinaryParser
    #
    # @param parser [BinaryParser] The BinaryParser to read the Amount from
    # @return [Amount] An Amount bundle exec rspec spec/binary-codec/types/st_object_spec.rb object
    # Creates an Amount instance from a parser.
    # @param parser [BinaryParser] The parser to read from.
    # @param _size_hint [Integer, nil] Optional size hint (unused).
    # @return [Amount] The created instance.
    def self.from_parser(parser, _size_hint = nil)
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
    # Returns the JSON representation of the Amount.
    # @param _definitions [Definitions, nil] Unused.
    # @param _field_name [String, nil] Optional field name.
    # @return [String, Hash] The JSON representation.
    def to_json(_definitions = nil, _field_name = nil)
      if is_native?
        bytes = @bytes.dup
        is_positive = (bytes[0] & 0x40) != 0
        sign = is_positive ? '' : '-'
        bytes[0] &= 0x3f

        msb = BinaryCodec.read_uint32be(bytes[0, 4])
        lsb = BinaryCodec.read_uint32be(bytes[4, 4])
        num = (msb << 32) | lsb

        return "#{sign}#{num}"
      end

      if is_iou?
        parser = BinaryParser.new(to_hex)
        mantissa_bytes = parser.read(8)
        currency = Currency.from_parser(parser)
        issuer = AccountId.from_parser(parser)

        b1 = mantissa_bytes[0]
        b2 = mantissa_bytes[1]

        is_positive = (b1 & 0x40) != 0
        exponent = ((b1 & 0x3f) << 2) + ((b2 & 0xff) >> 6) - 97

        mantissa_bytes[0] = 0
        mantissa_bytes[1] &= 0x3f
        
        # Convert mantissa bytes to integer
        mantissa_int = mantissa_bytes.reduce(0) { |acc, b| (acc << 8) + b }
        
        # value = mantissa * 10^exponent
        value = BigDecimal(mantissa_int) * (BigDecimal(10)**exponent)
        value = -value unless is_positive
        
        # Format the value string to match xrpl.js (stripping trailing .0)
        formatted_value = value.to_s('F').sub(/\.0$/, '')

        return {
          "value" => formatted_value,
          "currency" => currency.to_json,
          "issuer" => issuer.to_json
        }
      end

      if is_mpt?
        parser = BinaryParser.new(to_hex)
        leading_byte = parser.read(1)
        amount_bytes = parser.read(8)
        mpt_id = Hash192.from_parser(parser)

        is_positive = (leading_byte[0] & 0x40) != 0
        sign = is_positive ? '' : '-'

        msb = BinaryCodec.read_uint32be(amount_bytes[0, 4])
        lsb = BinaryCodec.read_uint32be(amount_bytes[4, 4])
        num = (msb << 32) | lsb

        return {
          "value" => "#{sign}#{num}",
          "mpt_issuance_id" => mpt_id.to_hex
        }
      end

      raise 'Invalid amount to construct JSON'
    end

    private

    # Type guard for AmountObjectIOU
    def self.is_amount_object_iou?(arg)
      return false unless arg.is_a?(::Hash)
      
      # Handle both string and symbol keys
      processed = arg.transform_keys(&:to_s)
      
      # Log for debugging
      # puts "DEBUG: Checking if #{processed.keys.inspect} is IOU"

      processed.key?('currency') &&
        processed.key?('issuer') &&
        processed.key?('value')
    end

    # Type guard for AmountObjectMPT
    def self.is_amount_object_mpt?(arg)
      return false unless arg.is_a?(::Hash)
      keys = arg.transform_keys(&:to_s).keys.sort

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

      decimal = amount.to_i
      unless decimal.zero?
        if decimal < MIN_XRP_DROPS || decimal > MAX_XRP_DROPS
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
    # amounts in financial transactions. Example failure:1.1234567891234567
    #
    # @param decimal [BigDecimal] A BigDecimal object
    # @raise [ArgumentError] if the value contains a decimal
    # @return [String] The decimal converted to a string without a decimal point
    def self.verify_no_decimal(decimal)
      # p is the number of significant digits
      # e is the power of 10 to multiply by the mantissa to get the number
      # BigDecimal('1.1234567891234567').precision => 17
      if decimal.precision > MAX_IOU_PRECISION
        raise ArgumentError, 'Decimal precision out of range'
      end
    end

    # Check if this amount is in units of Native Currency (XRP)
    #
    # @return [Boolean] true if Native (XRP)
    # Checks if the amount is a native XRP amount.
    # @return [Boolean] True if native, false otherwise.
    def is_native?
      (self.bytes[0] & 0x80).zero? && (self.bytes[0] & 0x20).zero?
    end

    # Check if this amount is in units of MPT
    #
    # @return [Boolean] true if MPT
    # Checks if the amount is a multi-purpose token (MPT).
    # @return [Boolean] True if MPT, false otherwise.
    def is_mpt?
      (self.bytes[0] & 0x80).zero? && (self.bytes[0] & 0x20) != 0
    end

    # Check if this amount is in units of IOU
    #
    # @return [Boolean] true if IOU
    # Checks if the amount is an IOU amount.
    # @return [Boolean] True if IOU, false otherwise.
    def is_iou?
      (self.bytes[0] & 0x80) != 0
    end

  end
end