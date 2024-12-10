# spec/address_codec/codec_spec.rb
require 'address-codec/codec'
require 'address-codec/xrp_codec'

RSpec.describe AddressCodec::XrpCodec do

  subject(:xrp_codec) { described_class.new }

  describe '#encode_seed' do
    it 'encodes ed25519 seed' do
      entropy = ["4C3A1D213FBDFB14C7C28D609469B341"].pack('H*').bytes
      encoded = xrp_codec.encode_seed(entropy, 'ed25519')

      expect(encoded).to eq("sEdTM1uX8pu2do5XvTnutH6HsouMaM2")
    end

    it 'encodes secp256k1 seed' do
      entropy = ["CF2DE378FBDD7E2EE87D486DFB5A7BFF"].pack('H*').bytes
      encoded = xrp_codec.encode_seed(entropy, 'secp256k1')

      expect(encoded).to eq("sn259rEFXrQrWyx3Q7XneWcwV6dfL")
    end
  end

end