# frozen_string_literal: true

RSpec.describe BinaryCodec::Blob do
  let(:blob_class) { BinaryCodec::Blob }

  describe 'Blob' do
    it 'encodes a Blob' do
      _1_byte = get_bytes(1)
      expect(blob_class.from(_1_byte).to_json).to eq(_1_byte)
      _16_bytes = get_bytes(16)
      expect(blob_class.from(_16_bytes).to_json).to eq(_16_bytes)
      _32_bytes = get_bytes(32)
      expect(blob_class.from(_32_bytes).to_json).to eq(_32_bytes)
      _64_bytes = get_bytes(64)
      expect(blob_class.from(_64_bytes).to_json).to eq(_64_bytes)
    end

    it 'decodes a Blob' do
      _16_bytes = get_bytes(16)
      expect(blob_class.from(_16_bytes).to_hex).to eq(_16_bytes)
      _128_bytes = get_bytes(128)
      expect(blob_class.from(_128_bytes).to_hex).to eq(_128_bytes)
    end
  end

  def get_bytes(size)
    "0F" * size
  end
end