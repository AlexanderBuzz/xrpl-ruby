# spec/binary_codec/bytes_list.rb
require 'binary-codec/serdes/bytes_list'

RSpec.describe BinaryCodec::BytesList do

  describe '#bytesListTest' do
    it 'is an Array of byte arrays (Array of Uint8Array equivalent)' do
      list = BinaryCodec::BytesList.new.put([0]).put([2, 3]).put([4, 5])
      expect(list.bytes_array).to be_a(Array)
      expect(list.bytes_array[0]).to be_a(Array)
    end

    it 'keeps track of its own length' do
      list = BinaryCodec::BytesList.new.put([0]).put([2, 3]).put([4, 5])
      expect(list.get_length).to eq(5)
    end

    it 'can join all arrays into one via to_bytes' do
      list = BinaryCodec::BytesList.new.put([0]).put([2, 3]).put([4, 5])
      joined = list.to_bytes
      expect(joined.length).to eq(5)
      expect(joined).to eq([0, 2, 3, 4, 5])
    end
  end

end