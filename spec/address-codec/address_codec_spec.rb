# spec/address_codec/codec_spec.rb
require 'core/core'
require 'address-codec/codec'
require 'address-codec/xrp_codec'
require 'address-codec/address_codec'
require 'json'

RSpec.describe AddressCodec::AddressCodec do

  subject(:address_codec) { described_class.new }

  let(:address_test_cases) do
    file_path = File.join(File.dirname(__FILE__), 'fixtures.json')
    JSON.parse(File.read(file_path))
  end

  before(:each) do
    @address_test_cases = address_test_cases['addressTestCases']
  end

  describe 'Address Codec' do
    it "can convert from classic address to xAddress" do
      @address_test_cases.each { |test_case|
        classic_address = test_case[0]
        tag = test_case[1] == false ? false : test_case[1]
        x_address = test_case[2]
        x_address_test = test_case[3]
        expect(address_codec.classic_address_to_x_address(classic_address, tag, false)).to eq(x_address)
        expect(address_codec.classic_address_to_x_address(classic_address, tag, true)).to eq(x_address_test)
      }
    end

    it "can encode an xAddress" do
      @address_test_cases.each { |test_case|
        account_id = address_codec.decode_account_id(test_case[0])
        tag = test_case[1] == false ? false : test_case[1]
        x_address = test_case[2]
        x_address_test = test_case[3]
        expect(address_codec.encode_x_address(account_id, tag, false)).to eq(x_address)
        expect(address_codec.encode_x_address(account_id, tag, true)).to eq(x_address_test)
      }
    end

    it "can convert a classic address to a xAddress" do
      @address_test_cases.each { |test_case|
        classic_address = test_case[0]
        tag = test_case[1] == false ? false : test_case[1]
        x_address = test_case[2]
        x_address_test = test_case[3]
        res = { classic_address: classic_address, tag: tag, test: false }
        expect(address_codec.x_address_to_classic_address(x_address)).to eq(res)
        res_test = { classic_address: classic_address, tag: tag, test: true }
        expect(address_codec.x_address_to_classic_address(x_address_test)).to eq(res_test)
      }
    end

    it "can decode an xAddress to a classic address" do

    end

    it "can validate a xAddress" do

    end

    it "handles invalid xAddresses" do
      bad_checksum_x_address = 'XVLhHMPHU98es4dbozjVtdWzVrDjtV5fdx1mHp98tDMoQXa'
      expect {
        address_codec.decode_x_address(bad_checksum_x_address)
      }.to raise_error(RuntimeError, 'checksum_invalid')

      bad_prefix_x_address = 'dGzKGt8CVpWoa8aWL1k18tAdy9Won3PxynvbbpkAqp3V47g'
      expect {
        address_codec.decode_x_address(bad_prefix_x_address)
      }.to raise_error(RuntimeError, 'Invalid X-address: bad prefix')
    end

  end

end
