# frozen_string_literal: true

RSpec.describe BinaryCodec::Uint do
  let(:uint8_class) { BinaryCodec::Uint8 }
  let(:uint16_class) { BinaryCodec::Uint16 }
  let(:uint32_class) { BinaryCodec::Uint32 }
  let(:uint64_class) { BinaryCodec::Uint64 }

  describe 'Uint8' do
    it 'decodes a Uint8 (int input)' do
      expect(uint8_class.from(0).value_of).to eq(0)
      expect(uint8_class.from(15).value_of).to eq(15)
      expect(uint8_class.from(255).value_of).to eq(255)
    end

    it 'decodes a Uint8 (hex input)' do
      expect(uint8_class.from_hex('00').value_of).to eq(0)
      expect(uint8_class.from_hex('0F').value_of).to eq(15)
      expect(uint8_class.from_hex('FF').value_of).to eq(255)
    end

    it 'renders a Uint8 as a number' do
      expect(uint8_class.from(0).to_json).to eq(0)
      expect(uint8_class.from(15).to_json).to eq(15)
      expect(uint8_class.from(255).to_json).to eq(255)
    end
  end

  describe 'Uint16' do
    it 'decodes a Uint16 (hex input)' do
      expect(uint16_class.from_hex('0000').value_of).to eq(0)
      expect(uint16_class.from_hex('000F').value_of).to eq(15)
      expect(uint16_class.from_hex('FFFF').value_of).to eq(65535)
    end

    it 'renders a Uint16 as a number' do
      expect(uint16_class.from(0).to_json).to eq(0)
      expect(uint16_class.from(15).to_json).to eq(15)
      expect(uint16_class.from(65535).to_json).to eq(65535)
    end
  end

  describe 'Uint32' do
    it 'decodes a Uint32 (hex input)' do
      expect(uint32_class.from_hex('00000000').value_of).to eq(0)
      expect(uint32_class.from_hex('0000000F').value_of).to eq(15)
      expect(uint32_class.from_hex('FFFFFFFF').value_of).to eq(4294967295)
    end

    it 'renders a Uint32 as a number' do
      expect(uint32_class.from(0).to_json).to eq(0)
      expect(uint32_class.from(15).to_json).to eq(15)
      expect(uint32_class.from(4294967295).to_json).to eq(4294967295)
    end
  end

  describe 'Uint64' do
    it 'decodes a Uint64 (hex input)' do
      expect(uint64_class.from_hex('0000000000000000').value_of).to eq(0)
      expect(uint64_class.from_hex('00000000000000FF').value_of).to eq(255)
      expect(uint64_class.from_hex('FFFFFFFFFFFFFFFF').value_of).to eq(18446744073709551615)
    end

    # A UInt64 stays a hex string: the value does not survive a round trip
    # through a JSON number.
    it 'renders a Uint64 as a hex string' do
      expect(uint64_class.from(0).to_json).to eq('0000000000000000')
      expect(uint64_class.from(255).to_json).to eq('00000000000000FF')
      expect(uint64_class.from(18446744073709551615).to_json).to eq('FFFFFFFFFFFFFFFF')
    end

    # The MPToken amount fields are the documented exception.
    it 'renders the MPToken amount fields in base 10' do
      expect(uint64_class.from(255).to_json(nil, 'MaximumAmount')).to eq('255')
      expect(uint64_class.from(255).to_json(nil, 'OutstandingAmount')).to eq('255')
      expect(uint64_class.from(74_565).to_json(nil, 'ConfidentialOutstandingAmount')).to eq('74565')
    end
  end

  # The PermissionValue of a DelegateSet is a UInt32 that carries a name:
  # a transaction type is its code plus one, the granular permissions start
  # at 65537. rippled renders the name, and accepts it.
  describe 'PermissionValue' do
    let(:uint32_class) { BinaryCodec::Uint32 }

    it 'resolves a transaction type to its code plus one' do
      expect(uint32_class.from('Payment').value_of).to eq(1)
      expect(uint32_class.from('TrustSet').value_of).to eq(21)
    end

    it 'resolves a granular permission' do
      expect(uint32_class.from('TrustlineAuthorize').value_of).to eq(65_537)
      expect(uint32_class.from('AccountDomainSet').value_of).to eq(65_540)
    end

    it 'renders the name for the PermissionValue field only' do
      expect(uint32_class.from(1).to_json(nil, 'PermissionValue')).to eq('Payment')
      expect(uint32_class.from(65_540).to_json(nil, 'PermissionValue')).to eq('AccountDomainSet')
      expect(uint32_class.from(1).to_json(nil, 'Sequence')).to eq(1)
    end

    it 'renders a code without a name as the number' do
      expect(uint32_class.from(0).to_json(nil, 'PermissionValue')).to eq(0)
    end

    it 'still takes a numeric string as a number' do
      expect(uint32_class.from('42').value_of).to eq(42)
    end
  end
  # rippled reads a UInt string as a whole decimal number and refuses the
  # rest (STParsedJSON, beast::lexicalCastThrow). The codec used to run every
  # String through #to_i, and wrote integers that do not fit the width.
  describe 'what it refuses' do
    # The readings of rippled 3.4.1 (STParsedJSON), which ripple-binary-codec
    # shares. Until 0.9.0 this codec read a UInt8/16/32 String in its full
    # width as hex ("00000065" was 101) and an unpadded UInt64 as decimal.
    it 'reads a UInt8, UInt16 or UInt32 String as decimal, as rippled does' do
      expect(uint32_class.from('101').value_of).to eq(101)
      expect(uint32_class.from('00000065').value_of).to eq(65)
      expect(uint16_class.from('0010').value_of).to eq(10)
      expect(uint8_class.from('255').value_of).to eq(255)
      expect(uint16_class.from('Payment').value_of).to eq(0)
      expect { uint32_class.from('0000000A') }.to raise_error(ArgumentError, /whole decimal number/)
    end

    it 'reads a UInt64 String as hex of any length, and as decimal in a base-10 field' do
      expect(uint64_class.from('00000000000036D6').value_of).to eq(0x36D6)
      expect(uint64_class.from('36d6').value_of).to eq(0x36D6)
      expect(uint64_class.from('100').value_of).to eq(0x100)
      expect(uint64_class.from('100', 'IndexNext').value_of).to eq(0x100)
      expect(uint64_class.from('100', 'MPTAmount').value_of).to eq(100)
      expect { uint64_class.from('36d6', 'MPTAmount') }.to raise_error(ArgumentError, /base 10/)
      expect { uint64_class.from('1' * 17) }.to raise_error(ArgumentError, /16 hex digits/)
    end

    it 'reads the field from the transaction when serialising' do
      expect(BinaryCodec.json_to_binary('IndexNext' => '36d6')).to eq(BinaryCodec.json_to_binary('IndexNext' => '00000000000036D6'))
      expect(BinaryCodec.json_to_binary('MPTAmount' => '100')).to end_with('0000000000000064')
    end

    # The name tables hang on the width; with the field known, only that
    # field's own names count.
    it 'takes a name only for the field it belongs to' do
      expect(BinaryCodec.json_to_binary('TransactionType' => 'Payment')).to eq('120000')
      expect(BinaryCodec.json_to_binary('PermissionValue' => 'TrustSet')).to eq(BinaryCodec.json_to_binary('PermissionValue' => 21))
      expect { BinaryCodec.json_to_binary('TicketSequence' => 'TrustSet') }.to raise_error(ArgumentError)
      expect { BinaryCodec.json_to_binary('TransferFee' => 'Payment') }.to raise_error(ArgumentError)
      expect { BinaryCodec.json_to_binary('TickSize' => 'tesSUCCESS') }.to raise_error(ArgumentError)
    end

    it 'reads an Int32 or Int64 String as signed decimal, and only that' do
      expect(BinaryCodec::Int32.from('-5').value_of).to eq(-5)
      expect(BinaryCodec::Int64.from('-9').value_of).to eq(-9)
      %w[DEAD 0x10 1.5].each do |bad|
        expect { BinaryCodec::Int64.from(bad) }.to raise_error(ArgumentError, /signed decimal/), bad
        expect { BinaryCodec::Int32.from(bad) }.to raise_error(ArgumentError, /signed decimal/), bad
      end
    end

    # As a decimal String, as rippled renders 64-bit values: a JSON reader
    # that holds numbers as doubles would round 2**53 + 1.
    it 'decodes an Int64 to a decimal String that goes back in unchanged' do
      [-9, 0, 2**53 + 1, 2**63 - 1].each do |n|
        int = BinaryCodec::Int64.from(n)
        expect(int.to_json).to eq(n.to_s)
        expect(BinaryCodec::Int64.from(int.to_json).to_hex).to eq(int.to_hex)
      end
    end

    # rippled 3.4.1 reads UInt32 and Int32 with beast::lexicalCast, which
    # skips a leading '+'. Its UInt8 and UInt16 parsers take a String that
    # does not start with a digit as a name, so "+5" is refused there, and
    # UInt64 is read with std::from_chars, which takes no sign.
    it 'accepts a leading plus sign where rippled does' do
      expect(BinaryCodec::Int32.from('+5').value_of).to eq(5)
      expect(BinaryCodec::Int64.from('+5').value_of).to eq(5)
      expect(uint32_class.from('+5').value_of).to eq(5)
      expect(BinaryCodec.uint32_value('+5')).to eq(5)
      expect { uint8_class.from('+5') }.to raise_error(ArgumentError)
      expect { uint16_class.from('+5') }.to raise_error(ArgumentError)
      expect { BinaryCodec::Uint128.from('+5') }.to raise_error(ArgumentError)
      expect { uint64_class.from('+36d6') }.to raise_error(ArgumentError)
      expect { uint64_class.from('+100', 'MPTAmount') }.to raise_error(ArgumentError)
      expect { uint32_class.from('++5') }.to raise_error(ArgumentError)
    end

    it 'refuses a String that is not a whole number' do
      %w[101junk 12.5 -1 0x10 abc].each do |bad|
        expect { uint32_class.from(bad) }.to raise_error(ArgumentError, /whole decimal number/), bad
      end
      expect { uint64_class.from('0x10') }.to raise_error(ArgumentError, /hex digits/)
    end

    it 'refuses a number that does not fit the width' do
      expect { uint32_class.from(2**32) }.to raise_error(ArgumentError, /0 to 4294967295/)
      expect { uint32_class.from('4294967296') }.to raise_error(ArgumentError, /0 to 4294967295/)
      expect { uint64_class.from('1' * 21, 'MPTAmount') }.to raise_error(ArgumentError, /0 to /)
      expect { uint8_class.from(256) }.to raise_error(ArgumentError)
      expect { uint32_class.from(-1) }.to raise_error(ArgumentError)
      expect(uint32_class.from(2**32 - 1).to_hex).to eq('FFFFFFFF')
    end

    it 'refuses a value that is neither a String nor an Integer' do
      [1.5, nil, [1]].each do |bad|
        expect { uint32_class.from(bad) }.to raise_error(StandardError, /Cannot construct/), bad.inspect
      end
    end

    it 'refuses a malformed Sequence in a transaction' do
      expect { BinaryCodec.json_to_binary('Sequence' => '101junk') }.to raise_error(ArgumentError)
    end
  end
end
