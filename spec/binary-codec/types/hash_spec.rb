# spec/binary_codec/types/hash_spec.rb
require 'binary-codec/types/serialized_type'
require 'binary-codec/types/hash'

RSpec.describe BinaryCodec::Hash do

  describe 'Hash128' do
    it 'has a static width member' do
      expect(BinaryCodec::Hash128.width).to eq(16)
    end

    it 'can be unset' do
      h1 = BinaryCodec::Hash128.from('')
      expect(h1.to_json).to eq('')
    end

    it 'can be compared against another' do
      h1 = BinaryCodec::Hash128.from('10000000000000000000000000000000')
      h2 = BinaryCodec::Hash128.from('20000000000000000000000000000000')
      h3 = BinaryCodec::Hash128.from('00000000000000000000000000000003')

      expect(h1.eq(h1)).to eq(true)
      expect(h1.lt(h2)).to eq(true)
      expect(h3.lt(h2)).to eq(true)
      expect(h2.gt(h1)).to eq(true)
      expect(h1.gt(h3)).to eq(true)
    end

    it 'throws when constructed from invalid hash length' do
      hex_value_15 = '100000000000000000000000000000'
      expect { BinaryCodec::Hash128.from(hex_value_15) }.to raise_error(StandardError, 'Invalid Hash length 15')
      hex_value_17 = '1000000000000000000000000000000000'
      expect { BinaryCodec::Hash128.from(hex_value_17) }.to raise_error(StandardError, 'Invalid Hash length 17')
    end
  end

  describe 'Hash160' do
    it 'has a static width member' do
      expect(BinaryCodec::Hash160.width).to eq(20)
    end

    # it 'is inherited by subclasses' do
    #  expect(AccountID.width).to eq(20)
    #  expect(Currency.width).to eq(20)
    # end

    it 'can be compared against another' do
      h1 = BinaryCodec::Hash160.from('1000000000000000000000000000000000000000')
      h2 = BinaryCodec::Hash160.from('2000000000000000000000000000000000000000')
      h3 = BinaryCodec::Hash160.from('0000000000000000000000000000000000000003')
      expect(h1.lt(h2)).to be true
      expect(h3.lt(h2)).to be true
    end

    it 'throws when constructed from invalid hash length' do
      expect {
        BinaryCodec::Hash160.from('10000000000000000000000000000000000000')
      }.to raise_error(StandardError, 'Invalid Hash length 19')

      expect {
        BinaryCodec::Hash160.from('100000000000000000000000000000000000000000')
      }.to raise_error(StandardError, 'Invalid Hash length 21')
    end
  end

  describe 'Hash191' do
    it 'has a static width member' do
      expect(BinaryCodec::Hash192.width).to eq(24)
    end

    # it 'has a ZERO_192 member' do
    #  expect(Hash192::ZERO_192.to_json).to eq( '000000000000000000000000000000000000000000000000')
    # end

    it 'can be compared against another' do
      h1 = BinaryCodec::Hash192.from('100000000000000000000000000000000000000000000000')
      h2 = BinaryCodec::Hash192.from('200000000000000000000000000000000000000000000000')
      h3 = BinaryCodec::Hash192.from('000000000000000000000000000000000000000000000003')

      expect(h1.lt(h2)).to be true
      expect(h3.lt(h2)).to be true
    end

    it 'throws when constructed from invalid hash length' do
      expect {
        BinaryCodec::Hash192.from('1000000000000000000000000000000000000000000000')
      }.to raise_error(StandardError, 'Invalid Hash length 23')

      expect {
        BinaryCodec::Hash192.from('10000000000000000000000000000000000000000000000000')
      }.to raise_error(StandardError, 'Invalid Hash length 25')
    end
  end

  describe 'Hash256' do
    it 'has a static width member' do
      expect(BinaryCodec::Hash256.width).to eq(32)
    end

    # it 'has a ZERO_256 member' do
    #  expect(Hash256::ZERO_256.to_json).to eq('0000000000000000000000000000000000000000000000000000000000000000')
    # end

    it 'supports getting the nibblet values at given positions' do
      h = BinaryCodec::Hash256.from('1359BD0000000000000000000000000000000000000000000000000000000000')

      expect(h.nibblet(0)).to eq(0x1)
      expect(h.nibblet(1)).to eq(0x3)
      expect(h.nibblet(2)).to eq(0x5)
      expect(h.nibblet(3)).to eq(0x9)
      expect(h.nibblet(4)).to eq(0x0b)
      expect(h.nibblet(5)).to eq(0xd)
    end
  end

end