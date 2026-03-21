# frozen_string_literal: true

RSpec.describe 'New Types' do
  describe 'Int32' do
    it 'handles positive values' do
      expect(BinaryCodec::Int32.from(1234).value_of).to eq(1234)
    end
    it 'handles negative values' do
      expect(BinaryCodec::Int32.from(-1234).value_of).to eq(-1234)
    end
    it 'handles max/min values' do
      expect(BinaryCodec::Int32.from(2147483647).value_of).to eq(2147483647)
      expect(BinaryCodec::Int32.from(-2147483648).value_of).to eq(-2147483648)
    end
  end

  describe 'Vector256' do
    it 'encodes and decodes an array of hashes' do
      hashes = ['0' * 64, '1' * 64]
      v = BinaryCodec::Vector256.from(hashes)
      expect(v.to_json).to eq(hashes)
    end
  end

  describe 'Issue' do
    it 'encodes and decodes a currency/issuer hash' do
      issue = {
        'currency' => 'XRP',
        'issuer' => 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh'
      }
      # XRP doesn't have an issuer usually in Issue type if it's 20 bytes,
      # but if it's 40 bytes it has both.
      # Actually in xrpl.js Issue is often used for IOU.
      # Currency 'XRP' is 20 bytes of 0s.
      v = BinaryCodec::Issue.from(issue)
      json = v.to_json
      expect(json['currency']).to eq('XRP')
      expect(json['issuer']).to eq('rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh')
    end
  end
end
