# frozen_string_literal: true

require_relative '../lib/xrpl-ruby'
require 'json'

client = XRPL::Client.new(XRPL::Client::TESTNET_URL)
client.connect

sleep 1

request_id = client.account_tx(
  account: 'rfvvroBArQixuN2z1eLAsZchXwMdo7Ds9A',
  ledger_index_min: -1,
  ledger_index_max: -1,
  limit: 5
)

puts JSON.pretty_generate(
  command: 'account_tx',
  request_id: request_id,
  network: XRPL::Client::TESTNET_URL,
  account: 'rfvvroBArQixuN2z1eLAsZchXwMdo7Ds9A',
  limit: 5
)

sleep 1
client.disconnect