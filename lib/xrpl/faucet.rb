# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

require_relative 'client'

module XRPL
  # Raised when a faucet request fails or funding does not complete in time.
  class FaucetError < StandardError; end

  # Funds (and thereby activates) a wallet on an XRP Ledger test network via the
  # public faucet, then waits until the account shows up on the ledger.
  #
  # This is the Ruby equivalent of the +fundWallet()+ helper used in the other
  # XRPL SDKs. It is intended for Testnet/Devnet only.
  #
  # @example Fund a fresh wallet on the Testnet
  #   client = XRPL::Client.new(:testnet)
  #   client.connect!
  #   result = XRPL.fund_wallet(client)
  #   result[:wallet].classic_address # => "r..."
  #   result[:balance]                # => 100000000000 (drops)
  class Faucet
    TESTNET_FAUCET = 'https://faucet.altnet.rippletest.net/accounts'
    DEVNET_FAUCET  = 'https://faucet.devnet.rippletest.net/accounts'

    DEFAULT_TIMEOUT = 40
    DEFAULT_POLL_INTERVAL = 2

    attr_reader :faucet_url

    # @param faucet_url [String] the faucet endpoint to POST to.
    def initialize(faucet_url: TESTNET_FAUCET)
      @faucet_url = faucet_url
    end

    # Convenience wrapper matching the tutorial call style.
    #
    # @param client [XRPL::Client] a connected client used to poll for funding.
    # @param wallet [Wallet::Wallet, nil] wallet to fund; a new one is generated when nil.
    # @return [Hash] +{ wallet:, balance: }+ (balance in drops).
    def self.fund_wallet(client, wallet = nil, faucet_url: TESTNET_FAUCET, **opts)
      new(faucet_url: faucet_url).fund_wallet(client, wallet, **opts)
    end

    # Funds (and activates) a wallet on a test network.
    #
    # @param client [XRPL::Client] a connected client used to poll for funding.
    # @param wallet [Wallet::Wallet, nil] wallet to fund; a new one is generated when nil.
    # @param amount [Numeric, String, nil] optional XRP amount to request.
    # @param timeout [Numeric] seconds to wait for the account to be funded.
    # @param poll_interval [Numeric] seconds between ledger polls.
    # @return [Hash] +{ wallet:, balance: }+ (balance in drops).
    # @raise [XRPL::FaucetError] if the faucet request fails or funding times out.
    def fund_wallet(client, wallet = nil, amount: nil, timeout: DEFAULT_TIMEOUT,
                    poll_interval: DEFAULT_POLL_INTERVAL)
      wallet ||= Wallet::Wallet.generate

      request_funds(wallet.classic_address, amount)
      balance = await_funding(
        client, wallet.classic_address,
        timeout: timeout, poll_interval: poll_interval
      )

      { wallet: wallet, balance: balance }
    end

    private

    # POSTs a funding request to the faucet for the given address.
    def request_funds(address, amount)
      body = { destination: address }
      body[:xrpAmount] = amount.to_s if amount

      http_post(@faucet_url, body)
    end

    # Polls the ledger until the account is funded, i.e. it exists and shows a
    # positive balance. (For a Testnet/get-started helper this simple
    # "funded = has a balance" rule is robust: unlike waiting for a strict
    # balance *increase*, it can never hang when a wallet already holds XRP.)
    def await_funding(client, address, timeout:, poll_interval:)
      deadline = monotonic_time + timeout

      loop do
        balance = current_balance(client, address)
        return balance if balance && balance.positive?

        if monotonic_time >= deadline
          raise FaucetError, "Account #{address} was not funded within #{timeout} seconds"
        end

        sleep poll_interval
      end
    end

    # Returns the account balance in drops, or nil if the account is not (yet)
    # found or a transient lookup error occurs.
    def current_balance(client, address)
      response = client.account_info_response(account: address, ledger_index: 'validated')
      drops = response.dig('result', 'account_data', 'Balance')
      drops && Integer(drops)
    rescue StandardError
      nil
    end

    def http_post(url, body)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'

      request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
      request.body = JSON.generate(body)

      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        raise FaucetError, "Faucet request failed: #{response.code} #{response.message}"
      end

      JSON.parse(response.body)
    rescue JSON::ParserError
      {}
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end

  # Top-level convenience mirroring the other SDKs' +fundWallet()+ sugar.
  #
  # @see Faucet#fund_wallet
  def self.fund_wallet(client, wallet = nil, **opts)
    Faucet.fund_wallet(client, wallet, **opts)
  end
end
