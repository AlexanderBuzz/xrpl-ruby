# frozen_string_literal: true

RSpec.describe BinaryCodec::AccountId do
  let(:account_id_class) { BinaryCodec::AccountId }
  let(:json_address) { "r9cZA1mLK5R5Am25ArfXFmqgNwjZgnfk59" }
  let(:hex_address) { "5E7B112523F68D2F5E879DB4EAC51C6698A69304" }

  describe 'AccountId' do
    describe '.from_hex' do
      it 'decodes a hex string into a JSON address' do
        account_id = account_id_class.from_hex(hex_address)
        expect(account_id.to_json).to eq(json_address)
      end
    end

    describe '.from_json' do
      it 'encodes a JSON address into its hex string' do
        account_id = account_id_class.from(json_address)
        expect(account_id.to_hex).to eq(hex_address)
      end
    end
  end

end