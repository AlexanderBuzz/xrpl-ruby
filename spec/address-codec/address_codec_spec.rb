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

    it "can encode anxAddress" do

    end

    it "can currently encode a classic address to a xAddress" do
    end

    it "can decode an xAddress to a classic address" do

    end

    it "can validate a xAddress" do

    end

  end

end
