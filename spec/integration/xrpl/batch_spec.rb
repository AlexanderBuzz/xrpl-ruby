# frozen_string_literal: true

require 'spec_helper'

# A Batch of one account, and a swap between two accounts, on the Testnet
# (BatchV1_1). Fresh faucet wallets each run.
#
# A successful outer transaction does not mean the inner ones went through:
# each is looked up by its own ID and checked for its own result and its
# ParentBatchID.
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

  # Every inner transaction is looked up by its own ID: validated,
  # tesSUCCESS, and naming its Batch in ParentBatchID (XLS-56).
  def expect_every_inner_applied(batch, result)
    outer_hash = result.dig('result', 'hash')
    expect(outer_hash).to match(/\A\h{64}\z/)
    BinaryCodec.inner_transaction_ids(batch).each do |id|
      inner = client.tx_response(transaction: id)['result']
      expect(inner['validated']).to be(true), "inner transaction #{id} has to be validated"
      expect(inner.dig('meta', 'TransactionResult')).to eq('tesSUCCESS')
      expect(inner.dig('meta', 'ParentBatchID')).to eq(outer_hash)
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

    result = client.submit_and_wait(batch, wallet: alice, autofill: false)
    expect_validated(result)
    expect_every_inner_applied(batch, result)
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
    result = client.submit_and_wait(combined, wallet: alice, autofill: false)
    expect_validated(result)
    expect_every_inner_applied(combined, result)
  end

  # Ported from xrpl-php's BatchTest: an account with a signer list
  # (quorum 2) signs its part through two of its signers, whose signatures
  # combine_batch_signers puts into one BatchSigner entry.
  it 'has a signer list sign its part with several signers' do
    alice = XRPL.fund_wallet(client)[:wallet]
    bob = XRPL.fund_wallet(client)[:wallet]
    carol = Wallet::Wallet.generate
    dave = Wallet::Wallet.generate

    signer_list = { 'TransactionType' => 'SignerListSet', 'Account' => bob.classic_address, 'SignerQuorum' => 2,
                    'SignerEntries' => [carol, dave].map do |w|
                      { 'SignerEntry' => { 'Account' => w.classic_address, 'SignerWeight' => 1 } }
                    end }
    expect_validated(client.submit_and_wait(signer_list, wallet: bob))

    # Two signatures for Bob's entry, so the fee pays for two.
    batch = client.autofill(
      { 'TransactionType' => 'Batch', 'Account' => alice.classic_address,
        'Flags' => XRPL::Batch::FLAGS['Batch']['tfAllOrNothing'],
        'RawTransactions' => [payment(alice, bob, 1_000_000), payment(bob, alice, 2_000_000)] },
      batch_signatures: 2
    )
    by_carol = carol.sign_batch(batch, batch_account: bob.classic_address, multisign: true)
    by_dave = dave.sign_batch(batch, batch_account: bob.classic_address, multisign: true)
    combined = Wallet::Wallet.combine_batch_signers([by_dave, by_carol])

    expect(combined['BatchSigners'].size).to eq(1)
    expect(combined['BatchSigners'][0]['BatchSigner']['Signers'].size).to eq(2)

    result = client.submit_and_wait(combined, wallet: alice, autofill: false)
    expect_validated(result)
    expect_every_inner_applied(combined, result)
  end
end
