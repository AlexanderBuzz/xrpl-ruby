# frozen_string_literal: true

require_relative '../lib/xrpl-ruby'
require 'json'

client = XRPL::Client.new(XRPL::Client::TESTNET_URL)
client.connect

sleep 1

request_id = client.account_info(
  account: 'rfvvroBArQixuN2z1eLAsZchXwMdo7Ds9A',
  ledger_index: 'validated'
)

puts JSON.pretty_generate(
  command: 'account_info',
  request_id: request_id,
  network: XRPL::Client::TESTNET_URL,
  account: 'rfvvroBArQixuN2z1eLAsZchXwMdo7Ds9A'
)

sleep 1
client.disconnect