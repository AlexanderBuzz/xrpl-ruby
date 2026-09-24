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
end