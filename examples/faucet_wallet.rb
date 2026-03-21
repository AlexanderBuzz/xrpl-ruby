# frozen_string_literal: true

require_relative '../lib/xrpl-ruby'
require 'net/http'
require 'json'

# This example demonstrates how to create a new wallet and fund it using the XRPL Testnet faucet.

# 1. Generate a new wallet
puts "Generating new wallet..."
wallet = Wallet::Wallet.generate
puts "Address: #{wallet.classic_address}"
puts "Seed:    #{wallet.seed}"

# 2. Fund the wallet using the Testnet faucet
puts "\nFunding wallet via Testnet faucet..."
faucet_url = URI('https://faucet.altnet.rippletest.net/accounts')
begin
  http = Net::HTTP.new(faucet_url.host, faucet_url.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE # Disabling for testing environment issues
  
  request = Net::HTTP::Post.new(faucet_url.request_uri, { 'Content-Type' => 'application/json' })
  request.body = JSON.generate({ destination: wallet.classic_address })
  
  response = http.request(request)

  if response.is_a?(Net::HTTPSuccess)
    data = JSON.parse(response.body)
    puts "Faucet response: #{data}"
  else
    puts "Failed to fund wallet: #{response.code} #{response.message}"
    puts response.body
    exit 1
  end
rescue StandardError => e
  puts "Error connecting to faucet: #{e.message}"
  exit 1
end

# 3. Wait for validation and check balance
puts "\nWaiting for account to be funded..."
rpc_url = URI('https://s.altnet.rippletest.net:51234')

10.times do |i|
  print "."
  sleep 2

  begin
    http = Net::HTTP.new(rpc_url.host, rpc_url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE # Disabling for testing environment issues
    request = Net::HTTP::Post.new(rpc_url.request_uri, { 'Content-Type' => 'application/json' })
    request.body = JSON.generate({
      method: 'account_info',
      params: [{
        account: wallet.classic_address,
        ledger_index: 'validated'
      }]
    })

    rpc_response = http.request(request)
    if rpc_response.is_a?(Net::HTTPSuccess)
      rpc_data = JSON.parse(rpc_response.body)
      if rpc_data.dig('result', 'account_data')
        balance = rpc_data.dig('result', 'account_data', 'Balance').to_i / 1_000_000.0
        puts "\nAccount funded! Current balance: #{balance} XRP"
        break
      elsif rpc_data.dig('result', 'error') == 'actNotFound'
        # Still waiting
      else
        puts "\nUnexpected RPC response: #{rpc_data}"
      end
    end
  rescue StandardError => e
    puts "\nError checking balance: #{e.message}"
  end

  if i == 9
    puts "\nTimed out waiting for account funding. It might still be processing."
  end
end
