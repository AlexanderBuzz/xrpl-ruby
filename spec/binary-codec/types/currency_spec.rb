# spec/binary_codec/types/hash_spec.rb
require 'binary-codec/types/serialized_type'
require 'binary-codec/types/hash'
require 'binary-codec/types/currency'

Currency = BinaryCodec::Currency

RSpec.describe BinaryCodec::Currency do

  describe 'Currency' do
    it 'decoding allows dodgy XRP without throwing' do
      currency_code = '0000000000000000000000005852500000000000'
      expect(Currency.from(currency_code).to_json).to eq(currency_code)
    end

    it 'currency code with lowercase letters decodes to ISO code' do
      expect(Currency.from('xRp').to_json).to eq('xRp')
    end

    it 'currency codes with symbols decode to ISO code' do
      expect(Currency.from('x|p').to_json).to eq('x|p')
    end

    it 'currency code with non-standard symbols decodes to hex' do
      expect(Currency.from(':::').to_json).to eq('0000000000000000000000003A3A3A0000000000')
    end

    it 'currency codes can be exclusively standard symbols' do
      expect(Currency.from('![]').to_json).to eq('![]')
    end

    it 'currency codes with uppercase letters and 0-9 decode to ISO code' do
      expect(Currency.from('X8P').to_json).to eq('X8P')
      expect(Currency.from('USD').to_json).to eq('USD')
    end

    it 'handles currency codes with no contiguous zeroes in first 96 type code & reserved bits' do
      expect(Currency.from('0000000023410000000000005852520000000000').iso).to eq(nil)
    end

    it 'handles currency codes with no contiguous zeroes in last 40 reserved bits' do
      expect(Currency.from('0000000000000000000000005852527570656500').iso).to eq(nil)
    end

    it 'can be constructed from an Array' do
      xrp = Currency.new(Array.new(20, 0))
      expect(xrp.iso).to eq('XRP')
    end

    it 'can handle non-standard currency codes' do
      currency = '015841551A748AD2C1F76FF6ECB0CCCD00000000'
      expect(Currency.from(currency).to_json).to eq(currency)
    end

    it 'can handle other non-standard currency codes' do
      currency = '0000000000414C6F676F30330000000000000000'
      expect(Currency.from(currency).to_json).to eq(currency)
    end

    it 'throws on invalid representations' do
      expect { Currency.from(Array.new(19, 0)) }.to raise_error(StandardError)
      expect { Currency.from(1) }.to raise_error(StandardError)
      expect { Currency.from('00000000000000000000000000000000000000m') }.to raise_error(StandardError)
    end
  end

end