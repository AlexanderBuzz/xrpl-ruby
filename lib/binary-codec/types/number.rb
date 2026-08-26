# frozen_string_literal: true

module BinaryCodec
  # STNumber, the XRPL "Number" type.
  #
  # Always 12 bytes: a signed 64 bit mantissa followed by a signed 32 bit
  # exponent, both big endian. Used by the Vault and Lending Protocol fields
  # (AssetsAvailable, DebtTotal, PeriodicPayment and 14 others), which could
  # not be serialised at all before this class existed.
  #
  # Reference: xrpl.js packages/ripple-binary-codec/src/types/st-number.ts
  class Number < SerializedType
    BYTE_LENGTH = 12

    MIN_MANTISSA = 10**18
    MAX_MANTISSA = 10**19 - 1
    MAX_INT64 = 2**63 - 1

    MIN_EXPONENT = -32_768
    MAX_EXPONENT = 32_768

    # The exponent rippled uses to encode a canonical zero.
    DEFAULT_VALUE_EXPONENT = -2_147_483_648

    # Significant decimal digits rippled renders with.
    RANGE_LOG = 18

    NUMBER_PATTERN = /\A([-+]?)([0-9]+)(?:\.([0-9]+))?(?:[eE]([+-]?[0-9]+))?\z/

    def initialize(bytes = nil)
      bytes ||= Array.new(BYTE_LENGTH, 0)

      unless bytes.length == BYTE_LENGTH
        raise StandardError, "Invalid Number length #{bytes.length}"
      end

      super(bytes)
    end

    def self.from(value)
      return value if value.is_a?(Number)
      mantissa, exponent = extract_parts(value.to_s)
      mantissa, exponent = normalize(mantissa, exponent)

      Number.new(pack_signed(mantissa, 8) + pack_signed(exponent, 4))
    end

    def self.from_parser(parser, _size_hint = nil)
      Number.new(parser.read(BYTE_LENGTH))
    end

    def to_json(_definitions = nil, _field_name = nil)
      mantissa = self.class.unpack_signed(to_bytes[0, 8])
      exponent = self.class.unpack_signed(to_bytes[8, 4])

      return '0' if mantissa.zero? && exponent == DEFAULT_VALUE_EXPONENT

      negative = mantissa.negative?
      mantissa = mantissa.abs

      # A mantissa above 2^63-1 is shrunk by one digit before serialisation.
      # Restore it so the rendering matches rippled's internal value.
      if !mantissa.zero? && mantissa < MIN_MANTISSA
        mantissa *= 10
        exponent -= 1
      end

      sign = negative ? '-' : ''

      if exponent != 0 && (exponent < -(RANGE_LOG + 10) || exponent > -(RANGE_LOG - 10))
        return sign + scientific(mantissa, exponent)
      end

      sign + positional(mantissa, exponent)
    end

    # Scientific notation, with trailing zeros moved into the exponent.
    def self.scientific(mantissa, exponent)
      while !mantissa.zero? && (mantissa % 10).zero? && exponent < MAX_EXPONENT
        mantissa /= 10
        exponent += 1
      end

      "#{mantissa}e#{exponent}"
    end

    def scientific(mantissa, exponent)
      self.class.scientific(mantissa, exponent)
    end

    # Plain decimal notation, built by padding the digits out far enough that
    # the decimal point always lands inside the string.
    def positional(mantissa, exponent)
      pad_prefix = RANGE_LOG + 12
      pad_suffix = RANGE_LOG + 8

      raw = ('0' * pad_prefix) + mantissa.to_s + ('0' * pad_suffix)
      offset = exponent + pad_prefix + RANGE_LOG + 1

      integer = raw[0, offset].sub(/\A0+/, '')
      integer = '0' if integer.empty?
      fraction = raw[offset..].sub(/0+\z/, '')

      fraction.empty? ? integer : "#{integer}.#{fraction}"
    end

    # Split a number string into an unnormalised mantissa and exponent.
    def self.extract_parts(value)
      match = NUMBER_PATTERN.match(value)
      raise StandardError, "Unable to parse number from string: #{value}" unless match

      sign, int_part, frac_part, exp_part = match.captures

      digits = int_part.sub(/\A0+(?=.)/, '')
      exponent = 0

      unless frac_part.nil? || frac_part.empty?
        digits += frac_part
        exponent -= frac_part.length
      end
      exponent += exp_part.to_i unless exp_part.nil? || exp_part.empty?

      while digits.length > 1 && digits.end_with?('0')
        digits = digits[0..-2]
        exponent += 1
      end

      mantissa = digits.to_i
      mantissa = -mantissa if sign == '-'

      [mantissa, exponent]
    end

    # Bring mantissa and exponent into the range rippled expects.
    def self.normalize(mantissa, exponent)
      return [0, DEFAULT_VALUE_EXPONENT] if mantissa.zero?

      negative = mantissa.negative?
      m = mantissa.abs

      while m < MIN_MANTISSA && exponent > MIN_EXPONENT
        exponent -= 1
        m *= 10
      end

      last_digit = nil
      while m > MAX_MANTISSA
        raise StandardError, 'Mantissa and exponent are too large' if exponent >= MAX_EXPONENT

        exponent += 1
        last_digit = m % 10
        m /= 10
      end

      raise StandardError, 'Underflow: value too small to represent' if exponent < MIN_EXPONENT || m < MIN_MANTISSA
      raise StandardError, 'Exponent overflow: value too large to represent' if exponent > MAX_EXPONENT

      if m > MAX_INT64
        raise StandardError, 'Exponent overflow: value too large to represent' if exponent >= MAX_EXPONENT

        exponent += 1
        last_digit = m % 10
        m /= 10
      end

      if last_digit && last_digit >= 5
        m += 1

        if m > MAX_INT64
          raise StandardError, 'Exponent overflow: value too large to represent' if exponent >= MAX_EXPONENT

          last_digit = m % 10
          exponent += 1
          m /= 10
          m += 1 if last_digit >= 5
        end
      end

      [negative ? -m : m, exponent]
    end

    # Big endian two's complement.
    def self.pack_signed(value, byte_length)
      value += 2**(byte_length * 8) if value.negative?

      Array.new(byte_length) { |i| (value >> (8 * (byte_length - 1 - i))) & 0xFF }
    end

    def self.unpack_signed(bytes)
      value = bytes.reduce(0) { |acc, b| (acc << 8) + b }
      boundary = 2**(bytes.length * 8 - 1)

      value >= boundary ? value - 2**(bytes.length * 8) : value
    end
  end
end
