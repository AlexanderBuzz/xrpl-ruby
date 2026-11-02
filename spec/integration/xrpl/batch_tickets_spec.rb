# frozen_string_literal: true

require 'spec_helper'

# The sequence rules of autofill for a Batch, on the Testnet: an inner
# TicketCreate reserves its tickets before the next inner sequence, an outer
# Batch on a ticket consumes no sequence, and an inner transaction on a
# ticket carries Sequence 0. Ported from xrpl-php's BatchTest
# (testSequencesAroundTickets). Fresh faucet wallets each run.
RSpec.describe 'XRPL Batch sequences around tickets', :integration, :network do
  before do
    skip 'Set XRPL_NETWORK=1 to run network integration specs' unless ENV['XRPL_NETWORK'] == '1'
  end

  # Connects on first use. The after hook disconnects only what was
  # connected, so a skipped example never reaches the network.
  let(:client) { @client = XRPL::Client.new(XRPL::Client::TESTNET_URL).tap(&:connect!) }
  let(:all_or_nothing) { XRPL::Batch::FLAGS['Batch']['tfAllOrNothing'] }

  after do
    next unless @client

    @client.disconnect
    sleep 0.2
  end

  def payment(from, to, drops, extra = {})
    { 'RawTransaction' => { 'TransactionType' => 'Payment', 'Account' => from.classic_address,
                            'Destination' => to.classic_address, 'Amount' => drops.to_s }.merge(extra) }
  end

  # SHA512Half of 'TXN\0' and the inner transaction. Once #4 is in, this is
  # BinaryCodec.inner_transaction_ids.
  def inner_ids(batch)
    batch['RawTransactions'].map do |wrapper|
      blob = BinaryCodec.json_to_binary(wrapper['RawTransaction'])
      Digest::SHA512.digest("TXN\0#{[blob].pack('H*')}")[0, 32].unpack1('H*').upcase
    end
  end

  # Signs and submits the Batch, then checks the outer result and every
  # inner one. An applied inner transaction is a transaction of its own,
  # whose metadata names its Batch in ParentBatchID (XLS-56).
  def submit_and_expect_every_inner_applied(wallet, batch)
    signed = wallet.sign(batch)
    result = client.submit_and_wait(batch, wallet: wallet, autofill: false)
    expect(result.dig('result', 'meta', 'TransactionResult')).to eq('tesSUCCESS')

    inner_ids(batch).each do |id|
      inner = client.tx_response(transaction: id)['result']
      expect(inner['validated']).to be(true), "inner transaction #{id} has to be validated"
      expect(inner.dig('meta', 'TransactionResult')).to eq('tesSUCCESS')
      expect(inner.dig('meta', 'ParentBatchID')).to eq(signed['hash'])
    end
  end

  it 'skips the tickets of an inner TicketCreate and runs a Batch on a ticket' do
    alice = XRPL.fund_wallet(client)[:wallet]
    bob = XRPL.fund_wallet(client)[:wallet]

    # TicketCreate inside the Batch: the Payment after it has to skip its two tickets.
    batch = client.autofill({
      'TransactionType' => 'Batch', 'Account' => alice.classic_address, 'Flags' => all_or_nothing,
      'RawTransactions' => [
        { 'RawTransaction' => { 'TransactionType' => 'TicketCreate', 'Account' => alice.classic_address,
                                'TicketCount' => 2 } },
        payment(alice, bob, 1_000_000)
      ]
    })
    ticket_create = batch['RawTransactions'][0]['RawTransaction']
    expect(batch['RawTransactions'][1]['RawTransaction']['Sequence']).to eq(ticket_create['Sequence'] + 3)
    submit_and_expect_every_inner_applied(alice, batch)
    tickets = [ticket_create['Sequence'] + 1, ticket_create['Sequence'] + 2]

    # The outer Batch and one inner Payment on those tickets, one inner Payment on the sequence.
    batch = client.autofill({
      'TransactionType' => 'Batch', 'Account' => alice.classic_address, 'Flags' => all_or_nothing,
      'Sequence' => 0, 'TicketSequence' => tickets[0],
      'RawTransactions' => [payment(alice, bob, 1_000_000, 'TicketSequence' => tickets[1]),
                            payment(alice, bob, 2_000_000)]
    })
    expect(batch['RawTransactions'][0]['RawTransaction']['Sequence']).to eq(0)
    account_sequence = client.account_info_response(account: alice.classic_address, ledger_index: 'validated')
                             .dig('result', 'account_data', 'Sequence')
    expect(batch['RawTransactions'][1]['RawTransaction']['Sequence']).to eq(account_sequence)

    submit_and_expect_every_inner_applied(alice, batch)
  end
end
