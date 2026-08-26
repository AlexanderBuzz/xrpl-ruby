# frozen_string_literal: true

# STNumber, used by the Vault and Lending Protocol fields.
#
# The hex vectors below were produced independently by xrpl-php's Number
# implementation, which is itself checked against xrpl.js, so they are a
# cross-implementation reference rather than a recording of what this class
# happens to do.
RSpec.describe BinaryCodec::Number do
  let(:number) { BinaryCodec::Number }

  # value, serialised bytes, canonical rendering
  VECTORS = [
    ['0',                     '000000000000000080000000', '0'],
    ['1',                     '0DE0B6B3A7640000FFFFFFEE', '1'],
    ['-1',                    'F21F494C589C0000FFFFFFEE', '-1'],
    ['123.456',               '112209C76DE80000FFFFFFF0', '123.456'],
    ['-123.456',              'EEDDF63892180000FFFFFFF0', '-123.456'],
    ['1000000000000000000',   '0DE0B6B3A764000000000000', '1000000000000000000'],
    ['1e30',                  '0DE0B6B3A76400000000000C', '1e30'],
    ['3.141592653589793',     '2B992DDFA23248E8FFFFFFEE', '3.141592653589793']
  ].freeze

  describe 'serialisation' do
    VECTORS.each do |value, hex, _canonical|
      it "encodes #{value}" do
        expect(number.from(value).to_hex.upcase).to eq(hex)
      end

      it "decodes #{hex}" do
        expect(number.from_hex(hex).to_json).to eq(_canonical)
      end
    end
  end

  describe 'canonical form' do
    # A value can render differently from how it was written and still be the
    # same number; what matters is that re-encoding it yields the same bytes.
    {
      '0.000000000000000001' => '1e-18',
      '-2.5e-20' => '-25e-21',
      '9999999999999999999' => '1e19',
      '1234567890.0987654321' => '1234567890.098765432'
    }.each do |input, canonical|
      it "renders #{input} as #{canonical} and re-encodes to the same bytes" do
        bytes = number.from(input).to_hex

        expect(number.from_hex(bytes).to_json).to eq(canonical)
        expect(number.from(canonical).to_hex).to eq(bytes)
      end
    end
  end

  describe 'framing' do
    it 'is always twelve bytes' do
      expect(number.from('1').to_bytes.length).to eq(12)
      expect(number.from('0').to_bytes.length).to eq(12)
    end

    it 'refuses a buffer of the wrong length' do
      expect { number.new(Array.new(8, 0)) }.to raise_error(StandardError, /Invalid Number length/)
    end

    it 'refuses a value it cannot parse' do
      expect { number.from('not a number') }.to raise_error(StandardError, /Unable to parse/)
    end
  end

  describe 'inside an object' do
    it 'round-trips as a field of a transaction' do
      json = {
        'TransactionType' => 'VaultSet',
        'Account' => 'rBKPS4oLSaV2KVVuHH8EpQqMGgGefGFQs7',
        'AssetsMaximum' => '1000.5'
      }

      expect(BinaryCodec.binary_to_json(BinaryCodec.json_to_binary(json))).to eq(json)
    end
  end
end
