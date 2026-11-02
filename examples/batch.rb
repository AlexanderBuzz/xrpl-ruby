# frozen_string_literal: true

require_relative '../lib/xrpl-ruby'

# Batch (XLS-56) on the Testnet: first a Batch of one account, then a swap
# between two accounts, where the second account adds its BatchSigner.

client = XRPL::Client.new(:testnet)
client.connect!

def payment(from, to, drops)
  { 'RawTransaction' => { 'TransactionType' => 'Payment', 'Account' => from.classic_address,
                          'Destination' => to.classic_address, 'Amount' => drops.to_s } }
end

# A successful outer transaction does not mean the inner ones went through:
# under tfOnlyOne, tfUntilFailure or tfIndependent some may fail, and one that
# was not applied is not on the ledger at all. Check each by its own ID.
def report(client, label, batch, result)
  puts "#{label}: outer #{result.dig('result', 'meta', 'TransactionResult')}"
  BinaryCodec.inner_transaction_ids(batch).each do |id|
    inner = client.tx_response(transaction: id)
    outcome = inner.dig('result', 'meta', 'TransactionResult') || "not applied (#{inner.dig('result', 'error')})"
    puts "  inner #{id[0, 16]}... #{outcome}"
  end
end

puts 'Funding Alice and Bob...'
alice = XRPL.fund_wallet(client)[:wallet]
bob   = XRPL.fund_wallet(client)[:wallet]
all_or_nothing = XRPL::Batch::FLAGS['Batch']['tfAllOrNothing']

# 1. One account: Alice pays Bob twice. autofill prepares the inner
#    transactions; Alice signs the whole Batch like any other transaction.
batch = client.autofill({ 'TransactionType' => 'Batch', 'Account' => alice.classic_address,
                          'Flags' => all_or_nothing,
                          'RawTransactions' => [payment(alice, bob, 1_000_000), payment(alice, bob, 2_000_000)] })
report(client, 'One account', batch, client.submit_and_wait(batch, wallet: alice, autofill: false))

# 2. A swap: Alice pays Bob, Bob pays Alice. Bob signs the finished Batch,
#    so its fee has to include his signature before he signs:
#    batch_signatures: 1. Alice, the outer account, signs last.
swap = client.autofill({ 'TransactionType' => 'Batch', 'Account' => alice.classic_address,
                         'Flags' => all_or_nothing,
                         'RawTransactions' => [payment(alice, bob, 1_000_000), payment(bob, alice, 2_000_000)] },
                       batch_signatures: 1)
signed = Wallet::Wallet.combine_batch_signers([bob.sign_batch(swap)])
report(client, 'Swap', signed, client.submit_and_wait(signed, wallet: alice, autofill: false))

client.disconnect
