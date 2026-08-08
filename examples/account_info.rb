# frozen_string_literal: true

require_relative '../lib/xrpl-ruby'
require 'json'
require 'logger'

# Look up account information on the XRPL Testnet.

# The library is silent by default; opt in to diagnostics by passing a logger.
logger = Logger.new($stdout)
logger.formatter = proc { |_severity, _time, _progname, msg| "#{msg}\n" }

client = XRPL::Client.new(:testnet, logger: logger)
client.connect! # blocks until the connection is ready — no more sleep guesswork

response = client.account_info_response(
  account: 'rfvvroBArQixuN2z1eLAsZchXwMdo7Ds9A',
  ledger_index: 'validated'
)

puts JSON.pretty_generate(response)

client.disconnect
