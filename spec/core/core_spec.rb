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

    it 'converts DEADBEEF to hex' do
      expect(bytes_to_hex([222, 173, 190, 239])).to eq('DEADBEEF')
    end

    it 'raises an error for invalid hex string' do
      expect { hex_to_bytes('hello') }.to raise_error('Invalid hex string')
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

  describe '#hex_to_string' do
    it 'converts hex to string - deadbeef + X (HEX ASCII)' do
      expect(hex_to_string('646561646265656658', 'ascii')).to eq('deadbeefX')
    end

    it 'converts hex to string - deadbeef + ֍ (HEX)' do
      expect(hex_to_string('6465616462656566D68D')).to eq('deadbeef֍')
    end

    it 'throws an error for invalid hex string' do
      expect { hex_to_string('hello') }.to raise_error(ArgumentError, 'Invalid hex string')
    end
  end

  describe '#string_to_hex' do
    it 'converts string to hex - deadbeef + X (ASCII)' do
      expect(string_to_hex('deadbeefX')).to eq('646561646265656658')
    end

    it 'converts string to hex - deadbeef + ֍ (HEX)' do
      expect(string_to_hex('deadbeef֍')).to eq('6465616462656566D68D')
    end
  end

end