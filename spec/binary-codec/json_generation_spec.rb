# frozen_string_literal: true

require 'json'

# A codec type has two kinds of to_json caller. The codec asks for the value
# as rippled renders it (to_json(definitions, field_name), CLAUDE.md §2.8);
# Ruby's JSON library asks for a JSON text (to_json(state)). Before 0.9.1
# every type answered the codec's question in both cases, so JSON.generate
# produced invalid JSON (a Uint64 or AccountId unquoted) or raised TypeError
# (a Uint32 or an STObject).
RSpec.describe 'JSON generation of codec types' do
  fixtures = JSON.parse(File.read(File.join(__dir__, 'fixtures', 'codec-fixtures.json')))
  account = 'rPMh7Pi9ct699iZUTWaytJUoHcJ7cgyziK'

  values = {
    'Uint8' => [BinaryCodec::Uint8.from(5), 5],
    'Uint16' => [BinaryCodec::Uint16.from(10), 10],
    'Uint32' => [BinaryCodec::Uint32.from(2**32 - 1), 2**32 - 1],
    'Uint64' => [BinaryCodec::Uint64.from(0x36D6), '00000000000036D6'],
    'Int32' => [BinaryCodec::Int32.from(-5), -5],
    # a JSON reader with doubles would round this, so it is a String
    'Int64' => [BinaryCodec::Int64.from(2**53 + 1), '9007199254740993'],
    'AccountId' => [BinaryCodec::AccountId.from(account), account],
    'Amount' => [BinaryCodec::Amount.from('1000000'), '1000000'],
    'Blob' => [BinaryCodec::Blob.from('ABCD'), 'ABCD'],
    'Hash256' => [BinaryCodec::Hash256.from('A' * 64), 'A' * 64]
  }

  values.each do |type, (object, expected)|
    it "renders a #{type} as valid JSON inside JSON.generate" do
      json = JSON.generate({ 'x' => object, 'list' => [object] })

      expect(JSON.parse(json)).to eq('x' => expected, 'list' => [expected])
    end
  end

  it 'renders every fixture the way binary_to_json decodes it' do
    mismatches = %w[transactions accountState].flat_map do |group|
      fixtures[group].each_with_index.reject do |fixture, _|
        object = BinaryCodec::STObject.from_parser(BinaryCodec::BinaryParser.new(fixture['binary']))
        JSON.parse(JSON.generate(object)) == BinaryCodec.binary_to_json(fixture['binary'])
      end.map { |_, index| "#{group}[#{index}]" }
    end

    expect(mismatches).to be_empty
    expect(fixtures['transactions'].size + fixtures['accountState'].size).to eq(302)
  end

  it 'works with pretty_generate and dump as well' do
    object = BinaryCodec::STObject.from('Sequence' => 1, 'Account' => account)

    expect(JSON.parse(JSON.pretty_generate(object))).to eq('Sequence' => 1, 'Account' => account)
    expect(JSON.parse(JSON.dump([object]))).to eq([{ 'Sequence' => 1, 'Account' => account }])
  end

  # The codec's own calls must not change: they return the value, not text.
  it 'leaves the codec contract alone' do
    expect(BinaryCodec::Uint32.from(5).to_json).to eq(5)
    expect(BinaryCodec::Uint64.from(0x36D6).to_json(BinaryCodec::Definitions.instance, 'IndexNext'))
      .to eq('00000000000036D6')
    expect(BinaryCodec::STObject.from('Sequence' => 1).to_json).to eq('Sequence' => 1)
  end

  it 'answers as_json with the codec value, for encoders such as ActiveSupport' do
    expect(BinaryCodec::Uint32.from(5).as_json).to eq(5)
    expect(BinaryCodec::STObject.from('Sequence' => 1).as_json({})).to eq('Sequence' => 1)
  end
end
