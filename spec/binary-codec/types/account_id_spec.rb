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

    # rippled's STAccount: an unset field has no bytes and renders as ''.
    describe 'an unset field' do
      let(:zero_address) { 'rrrrrrrrrrrrrrrrrrrrrhoLvTp' }

      it 'is empty on the wire and in JSON' do
        tx = { 'TransactionType' => 'AccountSet', 'Account' => '', 'Fee' => '0', 'Sequence' => 0, 'SigningPubKey' => '' }

        hex = BinaryCodec.json_to_binary(tx)

        expect(hex).to end_with('8100')
        expect(BinaryCodec.binary_to_json(hex)).to eq(tx)
        expect(BinaryCodec.json_to_binary(BinaryCodec.binary_to_json(hex))).to eq(hex)
      end

      it 'stays empty inside an array' do
        tx = {
          'TransactionType' => 'AccountSet',
          'Account' => json_address,
          'Signers' => [{ 'Signer' => { 'Account' => '', 'SigningPubKey' => 'AB', 'TxnSignature' => 'CD' } }]
        }

        hex = BinaryCodec.json_to_binary(tx)

        expect(BinaryCodec.binary_to_json(hex)).to eq(tx)
      end

      it 'renders as an empty string through JSON.generate' do
        expect(JSON.generate('Account' => account_id_class.unset)).to eq('{"Account":""}')
      end

      it 'keeps the zero account at its full length' do
        hex = BinaryCodec.json_to_binary('Account' => zero_address)

        expect(hex).to eq("8114#{'00' * 20}")
        expect(BinaryCodec.binary_to_json(hex)).to eq('Account' => zero_address)
      end

      it 'stays 20 bytes at a fixed width position' do
        expect(account_id_class.unset.to_hex).to eq('00' * 20)
      end

      it 'refuses any other field length' do
        expect { BinaryCodec.binary_to_json("8113#{'00' * 19}") }.to raise_error(StandardError, /Invalid Hash length 19/)
        expect { BinaryCodec.binary_to_json("8115#{'00' * 21}") }.to raise_error(StandardError, /Invalid Hash length 21/)
      end
    end
  end

end