# frozen_string_literal: true

RSpec.describe BinaryCodec::STObject do
  let(:st_object_class) { BinaryCodec::STObject }
  # to_json returns a Hash. It used to return a JSON string, which forced a
  # parse on every nested value and turned native XRP amounts into integers.
  let(:memo_json) do
    {
      'Memo' => {
        'MemoType' => '687474703A2F2F6578616D706C652E636F6D2F6D656D6F2F67656E65726963',
        'MemoData' => '72656E74'
      }
    }
  end
  let(:memo_hex) { "EA7C1F687474703A2F2F6578616D706C652E636F6D2F6D656D6F2F67656E657269637D0472656E74E1" }

  describe 'STObject' do
    it 'decodes STObject from hex' do
      expect(st_object_class.from_hex(memo_hex).to_json).to eq(memo_json)
    end

    it 'encodes STObject to hex' do
      expect(st_object_class.from(memo_json).to_hex).to eq(memo_hex)
    end
  end
end
