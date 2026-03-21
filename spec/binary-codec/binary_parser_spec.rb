# frozen_string_literal: true

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
      double('FieldInstance', name: 'TestField', type: 'UInt8', is_variable_length_encoded: false)
    end

    it 'reads the value of a provided field' do
      expect(parser.read_field_value(mock_field)).to be_a(BinaryCodec::Uint8)
    end

    it 'raises an error if the field type is unsupported' do
      allow(mock_field).to receive(:type).and_return('UnsupportedType')
      expect { parser.read_field_value(mock_field) }.to raise_error(StandardError, /unsupported type UnsupportedType/)
    end
  end
end
