# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'XRPL payment lifecycle', :integration, :network do
  before do
    skip 'Set XRPL_NETWORK=1 to run network integration specs' unless ENV['XRPL_NETWORK'] == '1'
  end

  it 'funds two wallets and sends a Payment that ends up in a validated ledger' do
    client = XRPL::Client.new(XRPL::Client::TESTNET_URL)
    client.connect!

    sender   = XRPL.fund_wallet(client)[:wallet]
    receiver = XRPL.fund_wallet(client)[:wallet]

    payment = {
      'TransactionType' => 'Payment',
      'Account'         => sender.classic_address,
      'Destination'     => receiver.classic_address,
      'Amount'          => '1000000'
    }

    result = client.submit_and_wait(payment, wallet: sender)

    expect(result.dig('result', 'validated')).to be(true)
    expect(result.dig('result', 'meta', 'TransactionResult')).to eq('tesSUCCESS')
  ensure
    client&.disconnect
    sleep 0.2
  end
end
