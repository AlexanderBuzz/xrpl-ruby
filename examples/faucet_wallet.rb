# frozen_string_literal: true

require_relative '../lib/xrpl-ruby'
require 'logger'

# Create and fund a new wallet on the XRPL Testnet using the faucet helper.

# The library is silent by default; opt in to diagnostics by passing a logger.
logger = Logger.new($stdout)
logger.formatter = proc { |_severity, _time, _progname, msg| "#{msg}\n" }

client = XRPL::Client.new(:testnet, logger: logger)
client.connect! # blocks until the WebSocket connection is ready

puts 'Requesting a funded Testnet wallet...'
result = XRPL.fund_wallet(client)
wallet = result[:wallet]

puts "Address: #{wallet.classic_address}"
puts "Seed:    #{wallet.seed}"
puts "Balance: #{result[:balance] / 1_000_000.0} XRP"

client.disconnect
