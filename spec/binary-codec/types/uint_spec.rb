# spec/binary_codec/types/hash_spec.rb
require 'binary-codec/types/serialized_type'
require 'binary-codec/types/uint'

Uint8 = BinaryCodec::Uint8
Uint16 = BinaryCodec::Uint16
Uint32 = BinaryCodec::Uint32
Uint64 = BinaryCodec::Uint64

RSpec.describe BinaryCodec::Uint do

  describe 'Uint8' do
    it 'decodes a Uint8 (int input)' do
      expect(Uint8.from(0).value_of).to eq(0)
      expect(Uint8.from(15).value_of).to eq(15)
      expect(Uint8.from(255).value_of).to eq(255)
    end

    it 'decodes a Uint8 (hex input)' do
      expect(Uint8.from_hex('00').value_of).to eq(0)
      expect(Uint8.from_hex('0F').value_of).to eq(15)
      expect(Uint8.from_hex('FF').value_of).to eq(255)
    end

    it 'encodes a Uint8' do
      expect(Uint8.from(0).to_json).to eq('00')
      expect(Uint8.from(15).to_json).to eq('0F')
      expect(Uint8.from(255).to_json).to eq('FF')
    end
  end

  describe 'Uint16' do
    it 'decodes a Uint16 (hex input)' do
      expect(Uint8.from_hex('0000').value_of).to eq(0)
      expect(Uint8.from_hex('000F').value_of).to eq(15)
      expect(Uint8.from_hex('FFFF').value_of).to eq(65535)
    end

    it 'encodes a Uint16' do
      expect(Uint16.from(0).to_json).to eq('0000')
      expect(Uint16.from(15).to_json).to eq('000F')
      expect(Uint16.from(65535).to_json).to eq('FFFF')
    end
  end

  describe 'Uint32' do
    it 'decodes a Uint32 (hex input)' do
      expect(Uint32.from_hex('00000000').value_of).to eq(0)
      expect(Uint32.from_hex('0000000F').value_of).to eq(15)
      expect(Uint32.from_hex('FFFFFFFF').value_of).to eq(4294967295)
    end

    it 'encodes a Uint32' do
      expect(Uint32.from(0).to_json).to eq('00000000')
      expect(Uint32.from(15).to_json).to eq('0000000F')
      expect(Uint32.from(4294967295).to_json).to eq('FFFFFFFF')
    end
  end

  describe 'Uint64' do
    it 'decodes a Uint64 (hex input)' do
      expect(Uint64.from_hex('0000000000000000').value_of).to eq(0)
      expect(Uint64.from_hex('00000000000000FF').value_of).to eq(255)
      expect(Uint64.from_hex('FFFFFFFFFFFFFFFF').value_of).to eq(18446744073709551615)
    end

    it 'encodes a Uint64' do
      expect(Uint64.from(0).to_json).to eq('0000000000000000')
      expect(Uint64.from(255).to_json).to eq('00000000000000FF')
      expect(Uint64.from(18446744073709551615).to_json).to eq('FFFFFFFFFFFFFFFF')
    end
  end

end