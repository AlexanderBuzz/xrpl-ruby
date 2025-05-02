# spec/binary_codec/types/account_id_spec.rb
require 'address-codec/codec'
require 'address-codec/xrp_codec'
require 'address-codec/address_codec'
require 'binary-codec/enums/definitions'
require 'binary-codec/enums/fields'
require 'binary-codec/serdes/binary_parser'
require 'binary-codec/types/serialized_type'
require 'binary-codec/types/hash'
require 'binary-codec/types/account_id'
require 'binary-codec/types/currency'
require 'binary-codec/types/amount'
require 'json'

Amount = BinaryCodec::Amount

RSpec.describe BinaryCodec::Amount do

  describe 'Amount' do
    describe '.from_hex (decode XRP amount)' do
      it 'decodes a hex value to JSON (amount)' do
        expect(Amount.from_hex("4000000000000064").to_json).to eq("100")
        expect(Amount.from_hex("416345785D8A0000").to_json).to eq("100000000000000000")
      end
    end

    describe '.from_json (encode XRP amount)' do
      it 'encodes an amount (JSON) to hex' do
        expect(Amount.from("100").to_hex).to eq("4000000000000064")
        expect(Amount.from("100000000000000000").to_hex).to eq("416345785D8A0000")
      end
    end

    describe '.encode_currency_amount' do
      it 'encodes the JSON Amount object to the expected hex representation' do
        json = { "value" => "0.0000123", "currency" => "USD", "issuer" => "rDgZZ3wyprx4ZqrGQUkquE9Fs2Xs8XBcdw" }.transform_keys(&:to_sym)
        expect(Amount.from(json).to_hex).to eq("D3445EADB112E00000000000000000000000000055534400000000008B1CE810C13D6F337DAC85863B3D70265A24DF44")

        json = { "value" => "0.1", "currency" => "USD", "issuer" => "rDgZZ3wyprx4ZqrGQUkquE9Fs2Xs8XBcdw" }.transform_keys(&:to_sym)
        expect(Amount.from(json).to_hex).to eq("D4438D7EA4C6800000000000000000000000000055534400000000008B1CE810C13D6F337DAC85863B3D70265A24DF44")

        json = { "value" => "0", "currency" => "USD", "issuer" => "rDgZZ3wyprx4ZqrGQUkquE9Fs2Xs8XBcdw" }.transform_keys(&:to_sym)
        expect(Amount.from(json).to_hex).to eq("800000000000000000000000000000000000000055534400000000008B1CE810C13D6F337DAC85863B3D70265A24DF44")

        json = { "value" => "1", "currency" => "USD", "issuer" => "rDgZZ3wyprx4ZqrGQUkquE9Fs2Xs8XBcdw" }.transform_keys(&:to_sym)
        expect(Amount.from(json).to_hex).to eq("D4838D7EA4C6800000000000000000000000000055534400000000008B1CE810C13D6F337DAC85863B3D70265A24DF44")

        json = { "value" => "200", "currency" => "USD", "issuer" => "rDgZZ3wyprx4ZqrGQUkquE9Fs2Xs8XBcdw" }.transform_keys(&:to_sym)
        expect(Amount.from(json).to_hex).to eq("D5071AFD498D000000000000000000000000000055534400000000008B1CE810C13D6F337DAC85863B3D70265A24DF44")

        json = { "value" => "-2", "currency" => "USD", "issuer" => "rDgZZ3wyprx4ZqrGQUkquE9Fs2Xs8XBcdw" }.transform_keys(&:to_sym)
        expect(Amount.from(json).to_hex).to eq("94871AFD498D000000000000000000000000000055534400000000008B1CE810C13D6F337DAC85863B3D70265A24DF44")

        json = { "value" => "-200", "currency" => "USD", "issuer" => "rDgZZ3wyprx4ZqrGQUkquE9Fs2Xs8XBcdw" }.transform_keys(&:to_sym)
        expect(Amount.from(json).to_hex).to eq("95071AFD498D000000000000000000000000000055534400000000008B1CE810C13D6F337DAC85863B3D70265A24DF44")

        json = { "value" => "2.1", "currency" => "USD", "issuer" => "rDgZZ3wyprx4ZqrGQUkquE9Fs2Xs8XBcdw" }.transform_keys(&:to_sym)
        expect(Amount.from(json).to_hex).to eq("D48775F05A07400000000000000000000000000055534400000000008B1CE810C13D6F337DAC85863B3D70265A24DF44")

        json = { "value" => "123.456", "currency" => "USD", "issuer" => "rDgZZ3wyprx4ZqrGQUkquE9Fs2Xs8XBcdw" }.transform_keys(&:to_sym)
        expect(Amount.from(json).to_hex).to eq("D50462D36641000000000000000000000000000055534400000000008B1CE810C13D6F337DAC85863B3D70265A24DF44")

        json = { "value" => "211.0000123", "currency" => "USD", "issuer" => "rDgZZ3wyprx4ZqrGQUkquE9Fs2Xs8XBcdw" }.transform_keys(&:to_sym)
        expect(Amount.from(json).to_hex).to eq("D5077F08AFCEB4C000000000000000000000000055534400000000008B1CE810C13D6F337DAC85863B3D70265A24DF44")

        json = { "value" => "-12.34567", "currency" => "USD", "issuer" => "rDgZZ3wyprx4ZqrGQUkquE9Fs2Xs8XBcdw" }.transform_keys(&:to_sym)
        expect(Amount.from(json).to_hex).to eq("94C462D5077C860000000000000000000000000055534400000000008B1CE810C13D6F337DAC85863B3D70265A24DF44")
      end
    end

    describe '.decode_currency_amount' do
      it 'decodes the hex representation to the expected JSON Amount object' do
        hex = "D48775F05A07400000000000000000000000000055534400000000008B1CE810C13D6F337DAC85863B3D70265A24DF44"
        json = { "value" => "2.1", "currency" => "USD", "issuer" => "rDgZZ3wyprx4ZqrGQUkquE9Fs2Xs8XBcdw" }
        expect(Amount.from_hex(hex).to_json).to eq(json.to_s)

        hex = "D5077F08AFCEB4C000000000000000000000000055534400000000008B1CE810C13D6F337DAC85863B3D70265A24DF44"
        json = { "value" => "211.0000123", "currency" => "USD", "issuer" => "rDgZZ3wyprx4ZqrGQUkquE9Fs2Xs8XBcdw" }
        expect(Amount.from_hex(hex).to_json).to eq(json.to_s)
      end
    end
  end

end