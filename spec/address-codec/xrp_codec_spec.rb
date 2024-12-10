# spec/address_codec/codec_spec.rb
require 'core/core'
require 'address-codec/codec'
require 'address-codec/xrp_codec'

RSpec.describe AddressCodec::XrpCodec do

  subject(:xrp_codec) { described_class.new }

  describe '#encode_seed' do
    it 'can pass a type as second arg to encodeSeed' do
      ed_seed = 'sEdTM1uX8pu2do5XvTnutH6HsouMaM2'
      decoded = xrp_codec.decode_seed(ed_seed)
      type = 'ed25519'
      expect(bytes_to_hex(decoded[:bytes])).to eq('4C3A1D213FBDFB14C7C28D609469B341')
      expect(decoded[:type]).to eq(type)
      expect(xrp_codec.encode_seed(decoded[:bytes], type)).to eq(ed_seed)
    end

    it 'encodes secp256k1 seed' do
      entropy = hex_to_bytes("CF2DE378FBDD7E2EE87D486DFB5A7BFF")
      encoded = xrp_codec.encode_seed(entropy, 'secp256k1')
      expect(encoded).to eq("sn259rEFXrQrWyx3Q7XneWcwV6dfL")
    end

    it 'encodes low secp256k1 seed' do
      entropy = hex_to_bytes("00000000000000000000000000000000")
      encoded = xrp_codec.encode_seed(entropy, 'secp256k1')
      expect(encoded).to eq('sp6JS7f14BuwFY8Mw6bTtLKWauoUs')
    end

    it 'encodes high secp256k1 seed' do
      entropy = hex_to_bytes("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")
      encoded = xrp_codec.encode_seed(entropy, 'secp256k1')
      expect(encoded).to eq('saGwBRReqUNKuWNLpUAq8i8NkXEPN')
    end

    it 'encodes ed25519 seed' do
      entropy = hex_to_bytes("4C3A1D213FBDFB14C7C28D609469B341")
      encoded = xrp_codec.encode_seed(entropy, 'ed25519')
      expect(encoded).to eq("sEdTM1uX8pu2do5XvTnutH6HsouMaM2")
    end

    it 'encodes low ed25519 seed' do
      entropy = hex_to_bytes("00000000000000000000000000000000")
      encoded = xrp_codec.encode_seed(entropy, 'ed25519')
      expect(encoded).to eq('sEdSJHS4oiAdz7w2X2ni1gFiqtbJHqE')
    end

    it 'encodes high ed25519 seed' do
      entropy = hex_to_bytes('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF')
      encoded = xrp_codec.encode_seed(entropy, 'ed25519')
      expect(encoded).to eq('sEdV19BLfeQeKdEXyYA4NhjPJe6XBfG')
    end

    it 'attempting to encode a seed with less than 16 bytes of entropy throws' do
      expect {
        xrp_codec.encode_seed(hex_to_bytes('CF2DE378FBDD7E2EE87D486DFB5A7B'), 'secp256k1')
      }.to raise_error(RuntimeError, 'entropy must have length 16')
    end

    it 'attempting to encode a seed with more than 16 bytes of entropy throws' do
      expect {
        xrp_codec.encode_seed(hex_to_bytes('CF2DE378FBDD7E2EE87D486DFB5A7BFFFF'), 'secp256k1')
      }.to raise_error(RuntimeError, 'entropy must have length 16')
    end
  end

  describe '#decode_seed' do
    it 'can decode arbitrary seeds' do
      decoded = xrp_codec.decode_seed('sEdTM1uX8pu2do5XvTnutH6HsouMaM2')
      expect(bytes_to_hex(decoded[:bytes])).to eq('4C3A1D213FBDFB14C7C28D609469B341')
      expect(decoded[:type]).to eq('ed25519')

      decoded2 = xrp_codec.decode_seed('sn259rEFXrQrWyx3Q7XneWcwV6dfL')
      expect(bytes_to_hex(decoded2[:bytes])).to eq('CF2DE378FBDD7E2EE87D486DFB5A7BFF')
      expect(decoded2[:type]).to eq('secp256k1')
    end

    it 'can decode an Ed25519 seed' do
      decoded = xrp_codec.decode_seed('sEdTM1uX8pu2do5XvTnutH6HsouMaM2')
      expect(bytes_to_hex(decoded[:bytes])).to eq('4C3A1D213FBDFB14C7C28D609469B341')
      expect(decoded[:type]).to eq('ed25519')
    end

    it 'can decode a secp256k1 seed' do
      decoded = xrp_codec.decode_seed('sn259rEFXrQrWyx3Q7XneWcwV6dfL')
      expect(bytes_to_hex(decoded[:bytes])).to eq('CF2DE378FBDD7E2EE87D486DFB5A7BFF')
      expect(decoded[:type]).to eq('secp256k1')
    end
  end

  describe '#encode_account_id' do
    it 'can encode an AccountID' do
      encoded = xrp_codec.encode_account_id(
        hex_to_bytes('BA8E78626EE42C41B46D46C3048DF3A1C3C87072')
      )
      expect(encoded).to eq('rJrRMgiRgrU6hDF4pgu5DXQdWyPbY35ErN')
    end

    it 'unexpected length should throw' do
      expect {
        xrp_codec.encode_account_id(hex_to_bytes('ABCDEF'))
      }.to raise_error(
             RuntimeError,
             'unexpected_payload_length: bytes.length does not match expected_length. Ensure that the bytes are a Uint8Array.'
           )
    end

    it 'can translate between BA8E78626EE42C41B46D46C3048DF3A1C3C87072 and rJrRMgiRgrU6hDF4pgu5DXQdWyPbY35ErN' do
      actual = xrp_codec.encode_account_id(hex_to_bytes('BA8E78626EE42C41B46D46C3048DF3A1C3C87072'))
      expect(actual).to eq('rJrRMgiRgrU6hDF4pgu5DXQdWyPbY35ErN')
    end
  end

  describe '#decode_account_id' do
    it 'can decode an AccountID' do
      decoded = xrp_codec.decode_account_id('rJrRMgiRgrU6hDF4pgu5DXQdWyPbY35ErN')
      expect(bytes_to_hex(decoded)).to eq('BA8E78626EE42C41B46D46C3048DF3A1C3C87072')
    end

    it 'can translate between rJrRMgiRgrU6hDF4pgu5DXQdWyPbY35ErN and BA8E78626EE42C41B46D46C3048DF3A1C3C87072' do
      buf = xrp_codec.decode_account_id('rJrRMgiRgrU6hDF4pgu5DXQdWyPbY35ErN')
      expect(bytes_to_hex(buf)).to eq('BA8E78626EE42C41B46D46C3048DF3A1C3C87072')
    end
  end

  describe '#encode_node_public' do
    it 'can encode a NodePublic' do
      bytes = hex_to_bytes('0388E5BA87A000CB807240DF8C848EB0B5FFA5C8E5A521BC8E105C0F0A44217828')
      encoded = xrp_codec.encode_node_public(bytes)
      expect(encoded).to eq('n9MXXueo837zYH36DvMc13BwHcqtfAWNJY5czWVbp7uYTj7x17TH')
    end

    it 'can translate between 0388E5BA87A000CB807240DF8C848EB0B5FFA5C8E5A521BC8E105C0F0A44217828 and n9MXXueo837zYH36DvMc13BwHcqtfAWNJY5czWVbp7uYTj7x17TH' do
      actual = xrp_codec.encode_node_public(hex_to_bytes('0388E5BA87A000CB807240DF8C848EB0B5FFA5C8E5A521BC8E105C0F0A44217828'))
      expect(actual).to eq('n9MXXueo837zYH36DvMc13BwHcqtfAWNJY5czWVbp7uYTj7x17TH')
    end
  end

  describe '#decode_node_public' do
    it 'can decode a NodePublic' do
      decoded = xrp_codec.decode_node_public('n9MXXueo837zYH36DvMc13BwHcqtfAWNJY5czWVbp7uYTj7x17TH')
      expect(bytes_to_hex(decoded)).to eq('0388E5BA87A000CB807240DF8C848EB0B5FFA5C8E5A521BC8E105C0F0A44217828')
    end

    it 'can translate between n9MXXueo837zYH36DvMc13BwHcqtfAWNJY5czWVbp7uYTj7x17TH and 0388E5BA87A000CB807240DF8C848EB0B5FFA5C8E5A521BC8E105C0F0A44217828' do
      buf = xrp_codec.decode_node_public('n9MXXueo837zYH36DvMc13BwHcqtfAWNJY5czWVbp7uYTj7x17TH')
      expect(bytes_to_hex(buf)).to eq('0388E5BA87A000CB807240DF8C848EB0B5FFA5C8E5A521BC8E105C0F0A44217828')
    end
  end

  describe 'valid_classic_address?' do
    it 'confirms a valid secp256k1 address' do
      expect(xrp_codec.valid_classic_address?('rU6K7V3Po4snVhBBaU29sesqs2qTQJWDw1')).to be true
    end

    it 'confirms a valid ed25519 address' do
      expect(xrp_codec.valid_classic_address?('rLUEXYuLiQptky37CqLcm9USQpPiz5rkpD')).to be true
    end

    it 'rejects an invalid address' do
      expect(xrp_codec.valid_classic_address?('rU6K7V3Po4snVhBBaU29sesqs2qTQJWDw2')).to be false
    end

    it 'rejects an empty address' do
      expect(xrp_codec.valid_classic_address?('')).to be false
    end
  end

  describe 'Special Cases' do
    it 'encodes 123456789 with version byte of 0' do
      encoded = xrp_codec.encode('123456789'.bytes, { versions: [0], expected_length: 9 })
      expect(encoded).to eq('rnaC7gW34M77Kneb78s')
    end

    it 'multiple versions with no expected length should throw' do
      expect {
        xrp_codec.decode('rnaC7gW34M77Kneb78s', { versions: [0, 1] })
      }.to raise_error(RuntimeError, 'expected_length is required because there are >= 2 possible versions')
    end

    it 'attempting to decode data with length < 5 should throw' do
      expect {
        xrp_codec.decode('1234', { versions: [0] })
      }.to raise_error(RuntimeError, 'invalid_input_size: decoded data must have length >= 5')
    end

    it 'attempting to decode data with unexpected version should throw' do
      expect {
        xrp_codec.decode('rnaC7gW34M77Kneb78s', { versions: [2] })
      }.to raise_error(RuntimeError, 'version_invalid: version bytes do not match any of the provided version(s)')
    end

    it 'invalid checksum should throw' do
      expect {
        xrp_codec.decode('123456789', { versions: [0, 1] })
      }.to raise_error(RuntimeError, 'checksum_invalid')
    end

    it 'empty payload should throw' do
      expect {
        xrp_codec.decode('', { versions: [0, 1] })
      }.to raise_error(RuntimeError, 'invalid_input_size: decoded data must have length >= 5')
    end

    it 'decode data' do
      decoded = xrp_codec.decode('rnaC7gW34M77Kneb78s', { versions: [0] })
      expect(decoded).to eq({ version: [0], bytes: '123456789'.bytes, type: nil })
    end

    it 'decode data with expected length' do
      decoded = xrp_codec.decode('rnaC7gW34M77Kneb78s', { versions: [0], expected_length: 9, })
      expect(decoded).to eq({ version: [0], bytes: '123456789'.bytes, type: nil })
    end

    it 'decode data with wrong expected length should throw' do
      expect {
        xrp_codec.decode('rnaC7gW34M77Kneb78s', { versions: [0], expected_length: 8 })
      }.to raise_error(RuntimeError, 'version_invalid: version bytes do not match any of the provided version(s)')

      expect {
        xrp_codec.decode('rnaC7gW34M77Kneb78s', { versions: [0], expected_length: 10 })
      }.to raise_error(RuntimeError, 'version_invalid: version bytes do not match any of the provided version(s)')
    end
  end

end