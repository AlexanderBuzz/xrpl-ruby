# spec/binary_codec/types/account_id_spec.rb
require 'address-codec/codec'
require 'address-codec/xrp_codec'
require 'address-codec/address_codec'
require 'binary-codec/types/serialized_type'
require 'binary-codec/types/hash'
require 'binary-codec/types/account_id'

AccountId = BinaryCodec::AccountId

RSpec.describe BinaryCodec::AccountId do

  JSON_ADDRESS = "r9cZA1mLK5R5Am25ArfXFmqgNwjZgnfk59".freeze
  HEX_ADDRESS = "5E7B112523F68D2F5E879DB4EAC51C6698A69304".freeze

  describe 'AccountId' do
    describe '.from_hex' do
      it 'decodes a hex string into a JSON address' do
        account_id = AccountId.from_hex(HEX_ADDRESS)
        expect(account_id.to_json).to eq(JSON_ADDRESS)
      end
    end

    describe '.from_json' do
      it 'encodes a JSON address into its hex string' do
        account_id = AccountId.from(JSON_ADDRESS)
        expect(account_id.to_hex).to eq(HEX_ADDRESS)
      end
    end
  end

end