# frozen_string_literal: true

require 'eventmachine'
require 'faye/websocket'
require 'json'
require 'securerandom'
require 'timeout'

module XRPL
  # Raised when the WebSocket connection fails to open (or errors) before it
  # becomes ready to accept requests.
  class ConnectionError < StandardError; end

  # Raised when a submitted transaction fails or cannot be confirmed as
  # included in a validated ledger.
  class TransactionError < StandardError; end

  class Client
    MAINNET_URL = 'wss://s1.ripple.com'
    TESTNET_URL = 'wss://s.altnet.rippletest.net:51233'
    DEVNET_URL = 'wss://s.devnet.rippletest.net:51233'

    NETWORK_URLS = {
      'mainnet' => MAINNET_URL,
      'testnet' => TESTNET_URL,
      'devnet' => DEVNET_URL
    }.freeze

    # Added to the current ledger index to set LastLedgerSequence during autofill.
    LEDGER_OFFSET = 20
    # Approximate seconds between validated ledgers; used when polling for finality.
    LEDGER_CLOSE_TIME = 3
    # Default fee (drops) if the server's fee cannot be determined.
    DEFAULT_FEE_DROPS = 10

    attr_reader :url, :connection

    # @param url [String, Symbol] a network alias (:testnet/:mainnet/:devnet) or a WebSocket URL.
    # @param logger [Logger, nil] optional logger for diagnostic messages. When nil
    #   (the default), the client stays silent — a library must not write to the
    #   host application's stdout uninvited. Pass e.g. +Logger.new($stdout)+ to opt in.
    def initialize(url, logger: nil)
      @url = resolve_url(url)
      @connection = nil
      @requests = {}
      @open = false
      @ready_queue = Queue.new
      @logger = logger
    end

    # Opens the WebSocket connection.
    #
    # By default this is non-blocking (preserving the previous behaviour) and
    # returns +self+. Pass <tt>wait: true</tt> (or use {#connect!}) to block
    # until the socket is actually open, so a following request can't race with
    # connection setup and hit "Not connected".
    #
    # @param wait [Boolean] block until the connection is open.
    # @param timeout [Numeric] seconds to wait when +wait+ is true.
    # @return [self]
    def connect(wait: false, timeout: 10)
      @open = false
      @ready_queue = Queue.new

      Thread.new { EM.run } unless EM.reactor_running?

      EM.next_tick do
        @connection = Faye::WebSocket::Client.new(@url)

        @connection.on :open do |event|
          @open = true
          @ready_queue.push(:open)
          log("Connected to #{@url}")
        end

        @connection.on :message do |event|
          handle_message(JSON.parse(event.data))
        end

        @connection.on :error do |event|
          @ready_queue.push([:error, event.message])
        end

        @connection.on :close do |event|
          @open = false
          @connection = nil
          log("Connection closed: #{event.code} #{event.reason}")
        end
      end

      wait_until_open(timeout: timeout) if wait
      self
    end

    # Opens the connection and blocks until it is ready to accept requests.
    #
    # @param timeout [Numeric] seconds to wait for the socket to open.
    # @return [self]
    def connect!(timeout: 10)
      connect(wait: true, timeout: timeout)
    end

    # @return [Boolean] whether the WebSocket connection is currently open.
    def open?
      @open
    end

    # Blocks the calling thread until the connection is open.
    #
    # @param timeout [Numeric] seconds to wait before giving up.
    # @return [true] once the socket is open.
    # @raise [XRPL::ConnectionError] if the connection reports an error first.
    # @raise [Timeout::Error] if the socket does not open within +timeout+.
    def wait_until_open(timeout: 10)
      return true if @open

      signal = Timeout.timeout(timeout) { @ready_queue.pop }
      if signal.is_a?(Array) && signal.first == :error
        raise ConnectionError, "WebSocket connection failed: #{signal.last}"
      end

      true
    rescue Timeout::Error
      raise Timeout::Error, "Connection did not open within #{timeout} seconds"
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

    def fee(**params)
      request('fee', **params)
    end

    def fee_response(**params)
      request_with_retry('fee', params)
    end

    def tx(**params)
      request('tx', **params)
    end

    def tx_response(**params)
      request_with_retry('tx', params)
    end

    # --- Transaction lifecycle (client-centric orchestration; see ADR-001) ---

    # Fills in the fields a transaction needs before signing: +Sequence+, +Fee+
    # and +LastLedgerSequence+. Existing values are never overwritten.
    #
    # @param transaction [Hash] the (string-keyed) transaction to complete.
    # @param signers_count [Integer] number of signatures for multisign fee scaling.
    # @return [Hash] a copy of the transaction with the missing fields filled in.
    def autofill(transaction, signers_count: 0)
      tx = transaction.dup
      tx['Sequence'] ||= fetch_sequence(tx.fetch('Account'))
      tx['Fee'] ||= calculate_fee(signers_count)
      tx['LastLedgerSequence'] ||= current_ledger_index + LEDGER_OFFSET
      tx
    end

    # Autofills (optional), signs with the given wallet and submits a transaction.
    #
    # @param transaction [Hash] the transaction to submit.
    # @param wallet [Wallet::Wallet] wallet used to sign.
    # @param autofill [Boolean] whether to autofill missing fields first.
    # @param fail_hard [Boolean] reject the transaction rather than queueing it.
    # @return [Hash] the raw +submit+ response.
    def submit(transaction, wallet:, autofill: true, fail_hard: false)
      prepared = prepare_for_submit(transaction, wallet: wallet, autofill: autofill)
      submit_blob(prepared[:tx_blob], fail_hard: fail_hard)
    end

    # Like {#submit}, but then polls the ledger until the transaction is final
    # (included in a validated ledger, or definitively failed/expired).
    #
    # @param transaction [Hash] the transaction to submit.
    # @param wallet [Wallet::Wallet] wallet used to sign.
    # @param autofill [Boolean] whether to autofill missing fields first.
    # @param fail_hard [Boolean] reject the transaction rather than queueing it.
    # @param timeout [Numeric] max seconds to wait for validation.
    # @return [Hash] the validated +tx+ response.
    # @raise [XRPL::TransactionError] if the transaction fails, expires or times out.
    def submit_and_wait(transaction, wallet:, autofill: true, fail_hard: false, timeout: 20)
      prepared = prepare_for_submit(transaction, wallet: wallet, autofill: autofill)
      last_ledger = prepared[:tx]['LastLedgerSequence']
      unless last_ledger
        raise ArgumentError, 'Transaction must contain a LastLedgerSequence for reliable submission'
      end

      response = submit_blob(prepared[:tx_blob], fail_hard: fail_hard)
      preliminary = response.dig('result', 'engine_result')

      wait_for_final_outcome(prepared[:hash], last_ledger, preliminary, timeout: timeout)
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

    # Emits a diagnostic message via the injected logger, or stays silent when
    # none was provided. The client never writes to stdout on its own.
    def log(message)
      @logger&.info(message)
    end

    # --- Transaction lifecycle helpers ---

    def prepare_for_submit(transaction, wallet:, autofill:)
      raise ArgumentError, 'wallet: is required to sign the transaction' if wallet.nil?

      tx = transaction.is_a?(Hash) ? transaction.dup : transaction
      tx = autofill(tx) if autofill && tx.is_a?(Hash)

      signed = wallet.sign(tx)
      { tx: tx, tx_blob: signed['tx_blob'], hash: signed['hash'] }
    end

    def submit_blob(tx_blob, fail_hard:, timeout: 10)
      # request_with_response has a keyword parameter (timeout:). If we pass the
      # params as a *trailing* hash without also filling the keyword slot, Ruby 3
      # and RSpec's verifying doubles treat that hash as keyword arguments and
      # reject it ("Invalid keyword arguments"). We therefore mirror the exact,
      # proven call shape used by #request_with_retry: a positional params
      # variable followed by an explicit `timeout:` keyword. String keys are the
      # JSON field names the `submit` command expects.
      params = { 'tx_blob' => tx_blob, 'fail_hard' => fail_hard }
      request_with_response('submit', params, timeout: timeout)
    end

    def fetch_sequence(account)
      response = account_info_response(account: account, ledger_index: 'current')
      sequence = response.dig('result', 'account_data', 'Sequence')
      raise TransactionError, "Could not determine Sequence for #{account}" unless sequence

      Integer(sequence)
    end

    def calculate_fee(signers_count)
      base = base_fee_drops
      total = signers_count.to_i.positive? ? base * (1 + signers_count.to_i) : base
      total.to_s
    end

    def base_fee_drops
      response = request_with_retry('fee')
      drops = response.dig('result', 'drops', 'open_ledger_fee') ||
              response.dig('result', 'drops', 'base_fee')
      drops ? Integer(drops) : DEFAULT_FEE_DROPS
    rescue StandardError
      DEFAULT_FEE_DROPS
    end

    def current_ledger_index
      response = request_with_retry('ledger_current')
      index = response.dig('result', 'ledger_current_index')
      raise TransactionError, 'Could not determine current ledger index' unless index

      Integer(index)
    end

    # Polls until the transaction is final. Checks the transaction result FIRST
    # (return once validated), then whether the ledger has passed
    # LastLedgerSequence — the reverse of xrpl-php, which can wrongly raise even
    # though the transaction validated. See ADR-001.
    def wait_for_final_outcome(tx_hash, last_ledger, preliminary_result, timeout:)
      deadline = monotonic_time + timeout

      loop do
        response = tx_lookup(tx_hash)
        if response
          error = response.dig('result', 'error') || response['error']
          if error.nil?
            return response if response.dig('result', 'validated')
          elsif error != 'txnNotFound'
            raise TransactionError,
                  "Transaction #{tx_hash} failed: #{error} (preliminary: #{preliminary_result})"
          end
        end

        latest = current_ledger_index
        if latest > last_ledger
          raise TransactionError,
                "Transaction #{tx_hash} did not validate: ledger #{latest} passed " \
                "LastLedgerSequence #{last_ledger} (preliminary: #{preliminary_result})"
        end

        if monotonic_time >= deadline
          raise TransactionError,
                "Timed out after #{timeout}s waiting for #{tx_hash} to validate " \
                "(preliminary: #{preliminary_result})"
        end

        sleep LEDGER_CLOSE_TIME
      end
    end

    def tx_lookup(tx_hash)
      request_with_retry('tx', { transaction: tx_hash })
    rescue StandardError
      nil
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
