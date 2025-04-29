# spec/binary_codec/binary_serializer_spec.rb
require 'binary-codec/enums/fields'
require 'binary-codec/enums/definitions'
require 'binary-codec/serdes/binary_serializer'

RSpec.describe BinaryCodec::BinarySerializer do

  let(:address_test_cases) do
    file_path = File.join(File.dirname(__FILE__), 'fixture/fixtures.json')
    JSON.parse(File.read(file_path))
  end

  #subject(:binary_serializer) { described_class.new }
  let(:deliver_min_tx) { JSON.parse(File.read(File.join('spec', 'binary-codec', 'fixtures', 'delivermin-tx.json'))) }
  let(:deliver_min_tx_binary) { JSON.parse(File.read(File.join('spec', 'binary-codec', 'fixtures', 'delivermin-tx-binary.json'))) }

  # before(:each) do
  #  @address_test_cases = address_test_cases['addressTestCases']
  # end

  it 'is temporary' do
    # puts "deliver_min_tx: #{deliver_min_tx}"
  end

  it 'can serialize DeliverMin' do
    # encode:
    #expect(encode(deliver_min_tx)).to eq(deliver_min_tx_binary)
  end

end