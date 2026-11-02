# frozen_string_literal: true

require 'spec_helper'

# Permission delegation (XLS-75, PermissionDelegationV1_1 enabled on Mainnet
# since 2026-10-08), on the Testnet. Isaac lets Alice send Payments for him;
# Alice then sends one with Account = Isaac and Delegate = Alice, signed with
# her own key. In rippled 3.4.1 the Sequence is Isaac's
# (Transactor::checkSeqProxy reads sfAccount), while the signature and the
# fee are Alice's (STTx::getInitiator, Transactor::getFeePayer).
# Fresh faucet wallets each run.
RSpec.describe 'XRPL permission delegation', :integration, :network do
  before do
    skip 'Set XRPL_NETWORK=1 to run network integration specs' unless ENV['XRPL_NETWORK'] == '1'
  end

  # Connects on first use. The after hook disconnects only a client that was
  # created, so a skipped example never reaches the network; it is assigned
  # before connect!, so a socket left by a failed connect is still closed.
  let(:client) { (@client = XRPL::Client.new(XRPL::Client::TESTNET_URL)).tap(&:connect!) }

  after do
    next unless @client

    @client.disconnect
    sleep 0.2
  end

  def balance(wallet)
    Integer(client.account_info_response(account: wallet.classic_address, ledger_index: 'validated')
                  .dig('result', 'account_data', 'Balance'))
  end

  def expect_validated(result)
    expect(result.dig('result', 'validated')).to be(true)
    expect(result.dig('result', 'meta', 'TransactionResult')).to eq('tesSUCCESS')
  end

  it 'lets a delegate send a Payment for the account that authorised it' do
    isaac = XRPL.fund_wallet(client)[:wallet]
    alice = XRPL.fund_wallet(client)[:wallet]
    bob = XRPL.fund_wallet(client)[:wallet]

    delegate_set = { 'TransactionType' => 'DelegateSet', 'Account' => isaac.classic_address,
                     'Authorize' => alice.classic_address,
                     'Permissions' => [{ 'Permission' => { 'PermissionValue' => 'Payment' } }] }
    expect_validated(client.submit_and_wait(delegate_set, wallet: isaac))

    before = { isaac: balance(isaac), alice: balance(alice), bob: balance(bob) }
    payment = { 'TransactionType' => 'Payment', 'Account' => isaac.classic_address,
                'Delegate' => alice.classic_address, 'Destination' => bob.classic_address, 'Amount' => '1000000' }
    prepared = client.autofill(payment)
    result = client.submit_and_wait(prepared, wallet: alice, autofill: false)

    expect_validated(result)
    expect(result.dig('result', 'tx_json', 'Delegate') || result.dig('result', 'Delegate')).to eq(alice.classic_address)
    fee = Integer(prepared['Fee'])
    expect(balance(bob) - before[:bob]).to eq(1_000_000)
    expect(before[:isaac] - balance(isaac)).to eq(1_000_000) # the amount, no fee
    expect(before[:alice] - balance(alice)).to eq(fee) # the delegate pays the fee
  end

  it 'refuses a delegate without the permission' do
    isaac = XRPL.fund_wallet(client)[:wallet]
    mallory = XRPL.fund_wallet(client)[:wallet]

    payment = { 'TransactionType' => 'Payment', 'Account' => isaac.classic_address,
                'Delegate' => mallory.classic_address, 'Destination' => mallory.classic_address,
                'Amount' => '1000000' }
    response = client.submit(payment, wallet: mallory)

    expect(response.dig('result', 'engine_result')).to eq('terNO_DELEGATE_PERMISSION')
  end
end
