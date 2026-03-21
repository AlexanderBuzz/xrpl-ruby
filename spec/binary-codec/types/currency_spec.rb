# frozen_string_literal: true

RSpec.describe BinaryCodec::Currency do
  let(:currency_class) { BinaryCodec::Currency }

  describe 'Currency' do
    it 'decoding allows dodgy XRP without throwing' do
      currency_code = '0000000000000000000000005852500000000000'
      expect(currency_class.from(currency_code).to_json).to eq(currency_code)
    end

    it 'currency code with lowercase letters decodes to ISO code' do
      expect(currency_class.from('xRp').to_json).to eq('xRp')
    end

    it 'currency codes with symbols decode to ISO code' do
      expect(currency_class.from('x|p').to_json).to eq('x|p')
    end

    it 'currency code with non-standard symbols decodes to hex' do
      expect(currency_class.from(':::').to_json).to eq('0000000000000000000000003A3A3A0000000000')
    end

    it 'currency codes can be exclusively standard symbols' do
      expect(currency_class.from('![]').to_json).to eq('![]')
    end

    it 'currency codes with uppercase letters and 0-9 decode to ISO code' do
      expect(currency_class.from('X8P').to_json).to eq('X8P')
      expect(currency_class.from('USD').to_json).to eq('USD')
    end

    it 'handles currency codes with no contiguous zeroes in first 96 type code & reserved bits' do
      expect(currency_class.from('0000000023410000000000005852520000000000').iso).to eq(nil)
    end

    it 'handles currency codes with no contiguous zeroes in last 40 reserved bits' do
      expect(currency_class.from('0000000000000000000000005852527570656500').iso).to eq(nil)
    end

    it 'can be constructed from an Array' do
      xrp = currency_class.new(Array.new(20, 0))
      expect(xrp.iso).to eq('XRP')
    end

    it 'can handle non-standard currency codes' do
      currency = '015841551A748AD2C1F76FF6ECB0CCCD00000000'
      expect(currency_class.from(currency).to_json).to eq(currency)
    end

    it 'can handle other non-standard currency codes' do
      currency = '0000000000414C6F676F30330000000000000000'
      expect(currency_class.from(currency).to_json).to eq(currency)
    end

    it 'throws on invalid representations' do
      expect { currency_class.from(Array.new(19, 0)) }.to raise_error(StandardError)
      expect { currency_class.from(1) }.to raise_error(StandardError)
      expect { currency_class.from('00000000000000000000000000000000000000m') }.to raise_error(StandardError)
    end
  end

end