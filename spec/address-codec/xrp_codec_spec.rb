# spec/address_codec/codec_spec.rb
require 'core/core'
require 'address-codec/codec'
require 'address-codec/xrp_codec'

RSpec.describe AddressCodec::XrpCodec do

  subject(:xrp_codec) { described_class.new }

  describe '#encode_seed' do
    it 'encodes ed25519 seed' do
      entropy = hex_to_bytes("4C3A1D213FBDFB14C7C28D609469B341")
      encoded = xrp_codec.encode_seed(entropy, 'ed25519')

      expect(encoded).to eq("sEdTM1uX8pu2do5XvTnutH6HsouMaM2")
    end

    it 'encodes secp256k1 seed' do
      entropy = hex_to_bytes("CF2DE378FBDD7E2EE87D486DFB5A7BFF")
      encoded = xrp_codec.encode_seed(entropy, 'secp256k1')

      expect(encoded).to eq("sn259rEFXrQrWyx3Q7XneWcwV6dfL")
    end

    it 'can encode an AccountID' do
      encoded = xrp_codec.encode_account_id(
        hex_to_bytes('BA8E78626EE42C41B46D46C3048DF3A1C3C87072')
      )

      expect(encoded).to eq('rJrRMgiRgrU6hDF4pgu5DXQdWyPbY35ErN')
    end

  end

end