# frozen_string_literal: true

require 'spec_helper'

RSpec.describe XRPL::Faucet, :integration, :network do
  before do
    skip 'Set XRPL_NETWORK=1 to run network integration specs' unless ENV['XRPL_NETWORK'] == '1'
  end

  it 'funds a freshly generated wallet on the Testnet' do
    client = XRPL::Client.new(XRPL::Client::TESTNET_URL)
    client.connect!

    result = XRPL.fund_wallet(client)

    expect(result[:wallet].classic_address).to start_with('r')
    expect(result[:balance]).to be > 0
  ensure
    client&.disconnect
    sleep 0.2
  end
end
