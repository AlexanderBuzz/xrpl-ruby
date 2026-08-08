# frozen_string_literal: true

require_relative '../lib/xrpl-ruby'
require 'logger'

# End-to-end: fund two wallets, then send a validated XRP Payment.

# The library is silent by default; opt in to diagnostics by passing a logger.
logger = Logger.new($stdout)
logger.formatter = proc { |_severity, _time, _progname, msg| "#{msg}\n" }

client = XRPL::Client.new(:testnet, logger: logger)
client.connect!

# 1. Get two funded wallets from the Testnet faucet.
puts 'Funding sender and receiver...'
sender   = XRPL.fund_wallet(client)[:wallet]
receiver = XRPL.fund_wallet(client)[:wallet]

# 2. Build a Payment transaction (1 XRP = 1,000,000 drops).
payment = {
  'TransactionType' => 'Payment',
  'Account'         => sender.classic_address,
  'Destination'     => receiver.classic_address,
  'Amount'          => '1000000'
}

# 3. Autofill (Sequence/Fee/LastLedgerSequence), sign, submit and wait for
#    the transaction to be included in a validated ledger.
puts 'Submitting payment and waiting for validation...'
result = client.submit_and_wait(payment, wallet: sender)

puts "Validated: #{result.dig('result', 'validated')}"
puts "Result:    #{result.dig('result', 'meta', 'TransactionResult')}"

client.disconnect
