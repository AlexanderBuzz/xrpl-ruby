# spec/core/core.rb
require 'core/core'

RSpec.describe Core do

  describe '#bytes_to_hex' do
    it 'encodes an empty array' do
      expect(bytes_to_hex([])).to eq('')
    end

    it 'encodes an array' do
      bytes = [72, 101, 108, 108, 111]
      expect(bytes_to_hex(bytes)).to eq('48656C6C6F')
    end
  end

  describe '#hex_to_bytes' do
    it 'encodes an empty string' do
      expect(hex_to_bytes('')).to eq([])
    end

    it 'encodes a string' do
      hex = '48656C6C6F'
      expect(hex_to_bytes(hex)).to eq([72, 101, 108, 108, 111])
    end
  end

  describe '#bin_to_hex' do
    it 'encodes a char/bin string' do
      bin = 'Hello'
      expect(bin_to_hex(bin)).to eq('48656C6C6F')
    end
  end

  describe '#hex_to_bin' do
    it 'encodes a hex string' do
      hex = '48656C6C6F'
      expect(hex_to_bin(hex)).to eq('Hello')
    end
  end

end