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

  describe 'Uint types' do
    it 'pads Uint64 correctly' do
      expect(BinaryCodec::Uint64.from(1).to_json).to eq('0000000000000001')
    end
    it 'pads Uint256 correctly' do
      expect(BinaryCodec::Uint256.from(1).to_json).to eq('0' * 63 + '1')
    end
  end

  describe 'Hash types' do
    it 'Hash128 to_json' do
      expect(BinaryCodec::Hash128.from('01' * 16).to_json).to eq('01' * 16)
    end
    it 'Hash128 with zeros to_json returns empty string per Ruby implementation' do
      expect(BinaryCodec::Hash128.from('0' * 32).to_json).to eq('')
    end
  end

  describe 'XChainBridge' do
    it 'encodes and decodes correctly' do
      bridge = {
        'LockingChainDoor' => 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
        'LockingChainIssue' => { 'currency' => 'XRP' },
        'IssuingChainDoor' => 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
        'IssuingChainIssue' => { 'currency' => 'XRP' }
      }
      v = BinaryCodec::XChainBridge.from(bridge)
      json = v.to_json
      expect(json['LockingChainDoor']).to eq('rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh')
      expect(json['LockingChainIssue']['currency']).to eq('XRP')
    end
  end
end
