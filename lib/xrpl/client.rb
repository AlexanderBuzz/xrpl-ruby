# frozen_string_literal: true

require 'eventmachine'
require 'faye/websocket'
require 'json'
require 'securerandom'
require 'timeout'

module XRPL
  class Client
    MAINNET_URL = 'wss://s1.ripple.com'
    TESTNET_URL = 'wss://s.altnet.rippletest.net:51233'
    DEVNET_URL = 'wss://s.devnet.rippletest.net:51233'

    NETWORK_URLS = {
      'mainnet' => MAINNET_URL,
      'testnet' => TESTNET_URL,
      'devnet' => DEVNET_URL
    }.freeze

    attr_reader :url, :connection

    def initialize(url)
      @url = resolve_url(url)
      @connection = nil
      @requests = {}
    end

    def connect
      Thread.new { EM.run } unless EM.reactor_running?
      
      EM.next_tick do
        @connection = Faye::WebSocket::Client.new(@url)

        @connection.on :open do |event|
          puts "Connected to #{@url}"
        end

        @connection.on :message do |event|
          handle_message(JSON.parse(event.data))
        end

        @connection.on :close do |event|
          puts "Connection closed: #{event.code} #{event.reason}"
          @connection = nil
        end
      end
    end

    def disconnect
      @connection&.close
    end

    def request(command, params = {})
      id = SecureRandom.uuid
      register_pending_request(id)
      payload = {
        id: id,
        command: command
      }.merge(params)

      send_message(payload)
      # TODO: Implement promise/future or callback for response
      id
    end

    def request_with_response(command, params = {}, timeout: 10)
      id = SecureRandom.uuid
      queue = Queue.new
      register_pending_request(id, queue: queue)

      payload = {
        id: id,
        command: command
      }.merge(params)

      send_message(payload)

      Timeout.timeout(timeout) { queue.pop }
    rescue Timeout::Error
      @requests.delete(id)
      raise Timeout::Error, "Request timed out after #{timeout} seconds"
    end

    def request_with_retry(command, params = {}, max_attempts: 3, timeout: 10,
                           retry_exceptions: [RuntimeError, Timeout::Error], **keyword_params)
      attempt = 0
      request_params = keyword_params.empty? ? params : params.merge(keyword_params)

      begin
        attempt += 1
        request_with_response(command, request_params, timeout: timeout)
      rescue *retry_exceptions => error
        raise error if attempt >= max_attempts

        retry
      end
    end

    def subscribe(**params)
      request('subscribe', **params)
    end

    def unsubscribe(**params)
      request('unsubscribe', **params)
    end

    def account_channels(**params)
      request('account_channels', **params)
    end

    def account_currencies(**params)
      request('account_currencies', **params)
    end

    def account_info(**params)
      request('account_info', **params)
    end

    def account_info_response(**params)
      request_with_retry('account_info', params)
    end

    def account_lines(**params)
      request('account_lines', **params)
    end

    def account_nfts(**params)
      request('account_nfts', **params)
    end

    def account_objects(**params)
      request('account_objects', **params)
    end

    def account_offers(**params)
      request('account_offers', **params)
    end

    def account_tx(**params)
      request('account_tx', **params)
    end

    def account_tx_response(**params)
      request_with_retry('account_tx', params)
    end

    def account_tx_all(**params)
      page_limit = params.delete(:page_limit)
      max_attempts = params.delete(:max_attempts) || 3
      timeout = params.delete(:timeout) || 10

      current_params = params.dup
      responses = []

      loop do
        response = request_with_retry('account_tx', current_params, max_attempts: max_attempts, timeout: timeout)
        responses << response

        marker = response.dig('result', 'marker')
        break unless marker
        break if page_limit && responses.size >= page_limit

        current_params = current_params.merge(marker: marker)
      end

      responses
    end

    def summarize_account_tx(response)
      result = response.fetch('result', {})
      transactions = Array(result['transactions'])

      {
        'ledger_index_min' => result['ledger_index_min'],
        'ledger_index_max' => result['ledger_index_max'],
        'transaction_count' => transactions.size,
        'validated' => result['validated'] == true,
        'marker_present' => !result['marker'].nil?
      }
    end

    def gateway_balances(**params)
      request('gateway_balances', **params)
    end

    def noripple_check(**params)
      request('noripple_check', **params)
    end

    def ledger(**params)
      request('ledger', **params)
    end

    def ledger_closed(**params)
      request('ledger_closed', **params)
    end

    def ledger_current(**params)
      request('ledger_current', **params)
    end

    def ledger_data(**params)
      request('ledger_data', **params)
    end

    def ledger_entry(**params)
      request('ledger_entry', **params)
    end

    private

    def resolve_url(input)
      return input unless input.is_a?(Symbol) || input.is_a?(String)

      network_key = input.to_s
      return NETWORK_URLS[network_key] if NETWORK_URLS.key?(network_key)

      return input if network_key.include?('://')

      if input.is_a?(Symbol)
        raise ArgumentError, "Unsupported network alias: #{input}"
      end

      input
    end

    def send_message(payload)
      raise "Not connected" unless @connection
      @connection.send(payload.to_json)
    end

    def handle_message(message)
      message_id = message['id']
      return unless message_id
      return unless @requests.key?(message_id)

      request_entry = @requests[message_id]
      request_entry[:queue]&.push(message) if request_entry.is_a?(Hash)
      @requests.delete(message_id)
    end

    def register_pending_request(id, queue: nil)
      @requests[id] = queue ? { queue: queue } : :pending
    end
  end
end
