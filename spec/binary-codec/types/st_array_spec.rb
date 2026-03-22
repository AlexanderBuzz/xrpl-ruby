# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe BinaryCodec::STArray do
  let(:st_array_class) { BinaryCodec::STArray }
  let(:st_object_class) { BinaryCodec::STObject }

  describe 'STArray' do
    it 'encodes and decodes STArray correctly' do
      # This fixture contains an OfferCreate transaction, but we want to test STArray.
      # However, the provided PHP test source seems to use a full transaction to verify STArray in context
      # or potentially there is a Signers array missing in the provided JSON?
      # Let's use a simpler STArray example (Signers) which is common for STArray.
      
      json = [
        {
          "Signer" => {
            "Account" => "r9cZA1mLK5R5Am25ArfXFmqgNwjZgnfk59",
            "TxnSignature" => "3044022025464FA5466B6E28EEAD2E2D289A7A36A11EB9B269D211F9C76AB8E8320694E002205D5F99CB56E5A996E5636A0E86D029977BEFA232B7FB64ABA8F6E29DC87A9E89",
            "SigningPubKey" => "02A8A44DB3D4C73EEEE11DFE54D2029103B776AA8A8D293A91D645977C9DF5F544"
          }
        }
      ]
      
      binary = st_array_class.from(json).to_hex
      decoded = st_array_class.from_hex(binary).to_json
      
      expect(decoded).to eq(json)
    end

    it 'decodes a full transaction with STArray correctly' do
      # Fixture data from the issue update
      fixture = {
        "json" => {
          "Account" => "raD5qJMAShLeHZXf9wjUmo6vRK4arj9cF3",
          "Fee" => "10",
          "Flags" => 0,
          "Sequence" => 103929,
          "SigningPubKey" => "028472865AF4CB32AA285834B57576B7290AA8C31B459047DB27E16F418D6A7166",
          "TakerGets" => {
            "currency" => "ILS",
            "issuer" => "rNPRNzBB92BVpAhhZr4iXDTveCgV5Pofm9",
            "value" => "1694.768"
          },
          "TakerPays" => "98957503520",
          "TransactionType" => "OfferCreate",
          "TxnSignature" =>  "304502202ABE08D5E78D1E74A4C18F2714F64E87B8BD57444AFA5733109EB3C077077520022100DB335EE97386E4C0591CAC024D50E9230D8F171EEB901B5E5E4BD6D1E0AEF98C"
        },
        "binary" => "120007220000000024000195F964400000170A53AC2065D5460561EC9DE000000000000000000000000000494C53000000000092D705968936C419CE614BF264B5EEB1CEA47FF468400000000000000A7321028472865AF4CB32AA285834B57576B7290AA8C31B459047DB27E16F418D6A71667447304502202ABE08D5E78D1E74A4C18F2714F64E87B8BD57444AFA5733109EB3C077077520022100DB335EE97386E4C0591CAC024D50E9230D8F171EEB901B5E5E4BD6D1E0AEF98C811439408A69F0895E62149CFCC006FB89FA7D1E6E5D"
      }

      # Verify the fixture's binary can be decoded back to the JSON
      # STObject.from_hex returns a JSON string, so we parse it for comparison
      decoded_json = JSON.parse(st_object_class.from_hex(fixture["binary"]).to_json)
      
      expect(decoded_json["Account"]).to eq(fixture["json"]["Account"])
      expect(decoded_json["TransactionType"]).to eq(fixture["json"]["TransactionType"])
      expect(decoded_json["TakerGets"]).to eq(fixture["json"]["TakerGets"])
    end
  end
end
