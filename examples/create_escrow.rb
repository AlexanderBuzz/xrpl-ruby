# frozen_string_literal: true

require_relative '../lib/xrpl-ruby'
require 'logger'

# Transaction models: an EscrowCreate, which has enough fields that a typo is
# easy to make and expensive to find out about from the server.

logger = Logger.new($stdout)
logger.formatter = proc { |_severity, _time, _progname, msg| "#{msg}\n" }

client = XRPL::Client.new(:testnet, logger: logger)
client.connect!

puts 'Funding sender and receiver...'
sender   = XRPL.fund_wallet(client)[:wallet]
receiver = XRPL.fund_wallet(client)[:wallet]

# XRPL time is seconds since 2000-01-01, not since the Unix epoch.
RIPPLE_EPOCH = 946_684_800
release_at = Time.now.to_i - RIPPLE_EPOCH + 120

escrow = XRPL::Transaction::EscrowCreate.new(
  account:      sender.classic_address,
  destination:  receiver.classic_address,
  amount:       '1000000',
  finish_after: release_at
)

# The format says Destination and Amount are required. Ask before submitting.
puts "Missing fields: #{escrow.missing_fields.inspect}"
escrow.validate!

# What the model produces is an ordinary transaction hash.
puts "As the ledger sees it: #{escrow.to_h}"

puts 'Submitting escrow and waiting for validation...'
result = client.submit_and_wait(escrow, wallet: sender)

puts "Validated: #{result.dig('result', 'validated')}"
puts "Result:    #{result.dig('result', 'meta', 'TransactionResult')}"

# Anything read back off the ledger can become a model again.
readback = XRPL::Transaction.from(result.dig('result', 'tx_json') || escrow.to_h)
puts "Round-tripped as: #{readback.class}"

client.disconnect
