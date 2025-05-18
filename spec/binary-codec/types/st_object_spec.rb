# frozen_string_literal: true

require 'address-codec/codec'
require 'address-codec/xrp_codec'
require 'address-codec/address_codec'
require 'binary-codec/enums/definitions'
require 'binary-codec/enums/fields'
require 'binary-codec/serdes/binary_parser'
require 'binary-codec/serdes/binary_serializer'
require 'binary-codec/serdes/bytes_list'
require 'binary-codec/types/serialized_type'
require 'binary-codec/types/hash'
require 'binary-codec/types/account_id'
require 'binary-codec/types/amount'
require 'binary-codec/types/blob'
require 'binary-codec/types/currency'
require 'binary-codec/types/st_object'
require 'binary-codec/types/uint'
require 'digest'

STObject = BinaryCodec::STObject

RSpec.describe BinaryCodec::STObject do

    Memo = {
      "MemoType": "687474703A2F2F6578616D706C652E636F6D2F6D656D6F2F67656E65726963",
      "MemoData": "72656E74"
    }
    MemoHex = "EA7C1F687474703A2F2F6578616D706C652E636F6D2F6D656D6F2F67656E657269637D0472656E74E1"

  before do
    # Do nothing
  end

  after do
    # Do nothing
  end

  describe 'STObject' do
    it 'decodes STObject' do
      expect(STObject.from_hex(MemoHex).to_json).to eq(Memo.to_s)
    end

    #it 'decodes STObject' do
    #  expect(STObject.from_json(Memo.to_s).to_hex).to eq(MemoHex)
    #end
  end

end
