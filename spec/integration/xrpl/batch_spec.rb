# frozen_string_literal: true

require 'spec_helper'

# A Batch of one account, and a swap between two accounts, on the Testnet
# (BatchV1_1). Fresh faucet wallets each run.
#
# A successful outer transaction does not mean the inner ones went through:
# each is looked up by its own ID and checked for its own result.
RSpec.describe 'XRPL Batch lifecycle', :integration, :network do
  before do
    skip 'Set XRPL_NETWORK=1 to run network integration specs' unless ENV['XRPL_NETWORK'] == '1'
  end

  let(:client) { XRPL::Client.new(XRPL::Client::TESTNET_URL).tap(&:connect!) }

  after do
    client.disconnect
    sleep 0.2
  end

  def payment(from, to, drops)
    { 'RawTransaction' => { 'TransactionType' => 'Payment', 'Account' => from.classic_address,
                            'Destination' => to.classic_address, 'Amount' => drops.to_s } }
  end

  def inner_results(batch)
    BinaryCodec.inner_transaction_ids(batch).map do |id|
      client.tx_response(transaction: id).dig('result', 'meta', 'TransactionResult')
    end
  end

  def expect_validated(result)
    expect(result.dig('result', 'validated')).to be(true)
    expect(result.dig('result', 'meta', 'TransactionResult')).to eq('tesSUCCESS')
  end

  it 'submits a Batch of one account' do
    alice = XRPL.fund_wallet(client)[:wallet]
    bob = XRPL.fund_wallet(client)[:wallet]

    batch = client.autofill(
      { 'TransactionType' => 'Batch', 'Account' => alice.classic_address,
        'Flags' => XRPL::Batch::FLAGS['Batch']['tfAllOrNothing'],
        'RawTransactions' => [payment(alice, bob, 1_000_000), payment(alice, bob, 2_000_000)] }
    )

    expect_validated(client.submit_and_wait(batch, wallet: alice, autofill: false))
    expect(inner_results(batch)).to eq(%w[tesSUCCESS tesSUCCESS])
  end

  it 'swaps between two accounts with a BatchSigner' do
    alice = XRPL.fund_wallet(client)[:wallet]
    bob = XRPL.fund_wallet(client)[:wallet]

    # Bob's signature is collected after the Batch is complete, so its fee
    # is set for it beforehand.
    batch = client.autofill(
      { 'TransactionType' => 'Batch', 'Account' => alice.classic_address,
        'Flags' => XRPL::Batch::FLAGS['Batch']['tfAllOrNothing'],
        'RawTransactions' => [payment(alice, bob, 1_000_000), payment(bob, alice, 2_000_000)] },
      batch_signatures: 1
    )
    combined = Wallet::Wallet.combine_batch_signers([bob.sign_batch(batch)])

    expect(combined['BatchSigners'].map { |e| e['BatchSigner']['Account'] }).to eq([bob.classic_address])
    expect_validated(client.submit_and_wait(combined, wallet: alice, autofill: false))
    expect(inner_results(combined)).to eq(%w[tesSUCCESS tesSUCCESS])
  end
end
