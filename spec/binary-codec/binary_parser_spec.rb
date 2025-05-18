# spec/binary_codec/binary_parser_spec.rb
#
require 'binary-codec/enums/fields'
require 'binary-codec/enums/definitions'
require 'binary-codec/serdes/binary_parser'

RSpec.describe BinaryCodec::BinaryParser do

  let(:binary_data) { "01020304" } # Binary data sample
  subject(:parser) { described_class.new(binary_data) }      # Create a parser instance

  describe '#read_uint8' do
    it 'reads an unsigned 8-bit integer from the binary data' do
      expect(parser.read_uint8).to eq(1) # First byte
      expect(parser.read_uint8).to eq(2) # Second byte
    end

    it 'raises an error if data is out of bounds' do
      4.times { parser.read_uint8 }
      expect { parser.read_uint8 }.to raise_error(StandardError, 'End of byte stream reached')
    end
  end

  describe '#read_variable_length' do
    before do
      allow(parser).to receive(:read_uint8).and_return(193, 1) # Mock `read_uint8` behavior
    end

    # it 'parses variable length values properly' do
    #  expect(parser.read_variable_length).to eq(257) # Based on mocked values
    # end

    # it 'raises an error with an invalid variable length indicator' do
    #  allow(parser).to receive(:read_uint8).and_return(255) # Invalid byte
    #  expect { parser.read_variable_length }.to raise_error(StandardError, 'Invalid variable length indicator')
    # end
  end

  describe '#read_field_value' do
    let(:mock_field) do
      double('FieldInstance', name: 'TestField', type: double('Type', name: 'Uint8'), is_variable_length_encoded: false)
    end

    it 'reads the value of a provided field' do
      allow(parser).to receive(:type_for_field).with(mock_field).and_return(double('SerializedType', from_parser: 123))
      expect(parser.read_field_value(mock_field)).to eq(123)
    end

    it 'raises an error if the field type is unsupported' do
      allow(parser).to receive(:type_for_field).with(mock_field).and_return(nil)
      expect { parser.read_field_value(mock_field) }.to raise_error(StandardError, /unsupported: \(TestField, Uint8\)/)
    end

    it 'raises an error if from_parser returns nil' do
      allow(parser).to receive(:type_for_field).with(mock_field).and_return(double('SerializedType', from_parser: nil))
      expect { parser.read_field_value(mock_field) }.to raise_error(StandardError, /from_parser for \(TestField, Uint8\) -> nil/)
    end
  end
end
