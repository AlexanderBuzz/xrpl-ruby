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

    it 'encodes a Uint8' do
      expect(uint8_class.from(0).to_json).to eq('00')
      expect(uint8_class.from(15).to_json).to eq('0F')
      expect(uint8_class.from(255).to_json).to eq('FF')
    end
  end

  describe 'Uint16' do
    it 'decodes a Uint16 (hex input)' do
      expect(uint16_class.from_hex('0000').value_of).to eq(0)
      expect(uint16_class.from_hex('000F').value_of).to eq(15)
      expect(uint16_class.from_hex('FFFF').value_of).to eq(65535)
    end

    it 'encodes a Uint16' do
      expect(uint16_class.from(0).to_json).to eq('0000')
      expect(uint16_class.from(15).to_json).to eq('000F')
      expect(uint16_class.from(65535).to_json).to eq('FFFF')
    end
  end

  describe 'Uint32' do
    it 'decodes a Uint32 (hex input)' do
      expect(uint32_class.from_hex('00000000').value_of).to eq(0)
      expect(uint32_class.from_hex('0000000F').value_of).to eq(15)
      expect(uint32_class.from_hex('FFFFFFFF').value_of).to eq(4294967295)
    end

    it 'encodes a Uint32' do
      expect(uint32_class.from(0).to_json).to eq('00000000')
      expect(uint32_class.from(15).to_json).to eq('0000000F')
      expect(uint32_class.from(4294967295).to_json).to eq('FFFFFFFF')
    end
  end

  describe 'Uint64' do
    it 'decodes a Uint64 (hex input)' do
      expect(uint64_class.from_hex('0000000000000000').value_of).to eq(0)
      expect(uint64_class.from_hex('00000000000000FF').value_of).to eq(255)
      expect(uint64_class.from_hex('FFFFFFFFFFFFFFFF').value_of).to eq(18446744073709551615)
    end

    it 'encodes a Uint64' do
      expect(uint64_class.from(0).to_json).to eq('0000000000000000')
      expect(uint64_class.from(255).to_json).to eq('00000000000000FF')
      expect(uint64_class.from(18446744073709551615).to_json).to eq('FFFFFFFFFFFFFFFF')
    end
  end
end