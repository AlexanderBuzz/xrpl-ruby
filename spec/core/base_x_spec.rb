# spec/core/base_x_spec.rb
require 'core/base_x'

RSpec.describe Core::BaseX do
  before do
    @alphabet = '0123456789abcdef'
    @base_x = Core::BaseX.new(@alphabet)
  end



  describe '#encode' do
    it 'encodes an empty string' do
      expect(@base_x.encode('')).to eq('0')
    end

    it 'encodes a single character' do
     expect(@base_x.encode('a')).to eq('61')
    end

   it 'encodes a string' do
     expect(@base_x.encode('test')).to eq('74657374')
   end
  end

  describe '#decode' do
    it 'decodes an empty string' do
      expect(@base_x.decode('')).to eq('')
    end

    it 'decodes a single character' do
      expect(@base_x.decode('61')).to eq('a')
    end

    it 'decodes a string' do
      expect(@base_x.decode('74657374')).to eq('test')
    end
  end

  describe '#decode with invalid character' do
    it 'raises an error' do
      expect { @base_x.decode('g') }.to raise_error(ArgumentError)
    end
  end


end