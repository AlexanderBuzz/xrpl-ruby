# spec/address_codec/codec_spec.rb
require 'address-codec/codec'
require 'address-codec/xrp_codec'

RSpec.describe AddressCodec::Codec do

  subject(:codec) { described_class.new }

  describe '#encode' do
    it 'encodes 123456789 with version byte of 0' do
      bytes = "123456789".bytes
      encoded = codec.encode(bytes, {
        versions: [0],
        expectedLength: 9,
      })
      expect(encoded).to eq('rnaC7gW34M77Kneb78s')
    end

    # TODO: Test exceptions

  end

  describe '#decode' do
    it 'decode data with expected length' do
      decoded = codec.decode('rnaC7gW34M77Kneb78s', {
        versions: [0],
        expectedLength: 9,
      })
      expect(decoded[:bytes]).to eq("123456789".bytes)
    end

    # TODO: Test exceptions

  end

end