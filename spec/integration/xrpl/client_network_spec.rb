# frozen_string_literal: true

require_relative '../../../lib/xrpl/client'

RSpec.describe XRPL::Client, :integration, :network do
  let(:client) { described_class.new(described_class::TESTNET_URL) }
  let(:known_account) { 'rfvvroBArQixuN2z1eLAsZchXwMdo7Ds9A' }

  before do
    skip 'Set XRPL_NETWORK=1 to run network integration specs' unless ENV['XRPL_NETWORK'] == '1'

    client.connect
    sleep 1
  end

  after do
    next unless ENV['XRPL_NETWORK'] == '1'

    client.disconnect
    sleep 0.2
  end

  it 'fetches account_info from testnet for known account' do
    response = client.account_info_response(account: known_account, ledger_index: 'validated')

    expect(response).to include('id', 'status', 'type', 'result')
    expect(response['status']).to eq('success')
    expect(response.dig('result', 'account_data', 'Account')).to eq(known_account)
  end

  it 'fetches account_tx first page from testnet for known account' do
    response = client.account_tx_response(
      account: known_account,
      ledger_index_min: -1,
      ledger_index_max: -1,
      limit: 5
    )

    expect(response).to include('id', 'status', 'type', 'result')
    expect(response['status']).to eq('success')
    expect(response.dig('result', 'transactions')).to be_a(Array)
  end
end