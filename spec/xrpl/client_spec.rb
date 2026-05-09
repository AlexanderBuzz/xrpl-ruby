# frozen_string_literal: true

require_relative '../../lib/xrpl/client'

describe XRPL::Client do
  let(:client) { described_class.new('wss://example.com') }

  describe '#request' do
    let(:connection) { instance_double(Faye::WebSocket::Client) }

    it 'returns request id and sends command payload' do
      sent_json = nil
      allow(connection).to receive(:send) { |payload| sent_json = JSON.parse(payload) }

      client.instance_variable_set(:@connection, connection)
      id = client.request('ping')

      expect(id).to be_a(String)
      expect(id).not_to be_empty
      expect(sent_json['id']).to eq(id)
      expect(sent_json['command']).to eq('ping')
    end

    it 'merges params into request payload' do
      sent_json = nil
      allow(connection).to receive(:send) { |payload| sent_json = JSON.parse(payload) }

      client.instance_variable_set(:@connection, connection)
      client.request('ledger', ledger_index: 'validated')

      expect(sent_json['command']).to eq('ledger')
      expect(sent_json['ledger_index']).to eq('validated')
      expect(sent_json['id']).to be_a(String)
    end

    it 'raises when not connected' do
      expect { client.request('ping') }.to raise_error(RuntimeError, 'Not connected')
    end

    it 'registers pending request keyed by generated id' do
      allow(connection).to receive(:send)

      client.instance_variable_set(:@connection, connection)
      id = client.request('ping')

      requests = client.instance_variable_get(:@requests)
      expect(requests[id]).to eq(:pending)
    end
  end

  describe '#request_with_retry' do
    it 'retries transient failures and succeeds within max attempts' do
      attempts = 0
      allow(client).to receive(:request_with_response) do
        attempts += 1
        raise RuntimeError, 'temporary transport failure' if attempts < 3

        { 'id' => 'ok', 'result' => { 'status' => 'success' } }
      end

      response = client.request_with_retry('account_info', { account: 'rAccount' }, max_attempts: 3)

      expect(response.dig('result', 'status')).to eq('success')
      expect(attempts).to eq(3)
    end

    it 'raises deterministic terminal failure after max attempts' do
      allow(client).to receive(:request_with_response).and_raise(RuntimeError, 'temporary transport failure')

      expect do
        client.request_with_retry('account_info', { account: 'rAccount' }, max_attempts: 2)
      end.to raise_error(RuntimeError, 'temporary transport failure')

      expect(client).to have_received(:request_with_response).exactly(2).times
    end
  end

  describe '#account_tx_all' do
    it 'continues pagination while marker exists and stops when marker is absent' do
      first_page = {
        'result' => {
          'transactions' => [{ 'hash' => 'A' }],
          'marker' => 'next-page-marker'
        }
      }
      second_page = {
        'result' => {
          'transactions' => [{ 'hash' => 'B' }]
        }
      }

      expect(client).to receive(:request_with_retry)
        .with('account_tx', hash_including(account: 'rAccount', limit: 2), max_attempts: 3, timeout: 10)
        .and_return(first_page)
      expect(client).to receive(:request_with_retry)
        .with('account_tx', hash_including(account: 'rAccount', limit: 2, marker: 'next-page-marker'), max_attempts: 3, timeout: 10)
        .and_return(second_page)

      responses = client.account_tx_all(account: 'rAccount', limit: 2)

      expect(responses).to eq([first_page, second_page])
    end

    it 'stops pagination when explicit page_limit is reached' do
      first_page = { 'result' => { 'transactions' => [{ 'hash' => 'A' }], 'marker' => 'm1' } }
      expect(client).to receive(:request_with_retry).once.and_return(first_page)

      responses = client.account_tx_all(account: 'rAccount', limit: 2, page_limit: 1)

      expect(responses).to eq([first_page])
    end
  end

  describe '#summarize_account_tx' do
    it 'returns deterministic summary shape and does not mutate caller response' do
      response = {
        'result' => {
          'ledger_index_min' => 1,
          'ledger_index_max' => 100,
          'validated' => true,
          'marker' => 'm1',
          'transactions' => [{ 'hash' => 'A' }, { 'hash' => 'B' }]
        }
      }
      original = Marshal.load(Marshal.dump(response))

      summary = client.summarize_account_tx(response)

      expect(summary).to eq(
        'ledger_index_min' => 1,
        'ledger_index_max' => 100,
        'transaction_count' => 2,
        'validated' => true,
        'marker_present' => true
      )
      expect(response).to eq(original)
    end
  end

  describe '#subscribe / #unsubscribe' do
    it 'delegates subscribe to request with subscribe command' do
      expect(client).to receive(:request).with('subscribe', streams: ['ledger'])
      client.subscribe(streams: ['ledger'])
    end

    it 'delegates unsubscribe to request with unsubscribe command' do
      expect(client).to receive(:request).with('unsubscribe', streams: ['ledger'])
      client.unsubscribe(streams: ['ledger'])
    end

    it 'returns delegated request value for both wrappers' do
      expect(client).to receive(:request).with('subscribe', streams: ['ledger']).and_return('sub-id')
      expect(client).to receive(:request).with('unsubscribe', streams: ['ledger']).and_return('unsub-id')

      expect(client.subscribe(streams: ['ledger'])).to eq('sub-id')
      expect(client.unsubscribe(streams: ['ledger'])).to eq('unsub-id')
    end
  end

  describe 'network constants and URL resolution' do
    it 'defines canonical network URL constants' do
      expect(described_class::MAINNET_URL).to eq('wss://s1.ripple.com')
      expect(described_class::TESTNET_URL).to eq('wss://s.altnet.rippletest.net:51233')
      expect(described_class::DEVNET_URL).to eq('wss://s.devnet.rippletest.net:51233')
    end

    it 'resolves known network aliases to canonical URLs' do
      expect(described_class.new(:mainnet).url).to eq(described_class::MAINNET_URL)
      expect(described_class.new('testnet').url).to eq(described_class::TESTNET_URL)
      expect(described_class.new(:devnet).url).to eq(described_class::DEVNET_URL)
    end

    it 'preserves explicit websocket URL inputs' do
      explicit_url = 'wss://example.org:6006'
      expect(described_class.new(explicit_url).url).to eq(explicit_url)
    end

    it 'raises ArgumentError for unknown network aliases' do
      expect { described_class.new(:stagingnet) }
        .to raise_error(ArgumentError, /Unsupported network alias: stagingnet/)
    end
  end

  describe 'response correlation foundation' do
    it 'correlates known response id and removes pending entry' do
      connection = instance_double(Faye::WebSocket::Client)
      allow(connection).to receive(:send)

      client.instance_variable_set(:@connection, connection)
      id = client.request('ledger')

      expect(client.instance_variable_get(:@requests)[id]).to eq(:pending)

      client.send(:handle_message, { 'id' => id, 'result' => { 'status' => 'success' } })

      expect(client.instance_variable_get(:@requests)).not_to have_key(id)
    end

    it 'ignores unknown response ids safely' do
      connection = instance_double(Faye::WebSocket::Client)
      allow(connection).to receive(:send)

      client.instance_variable_set(:@connection, connection)
      known_id = client.request('ping')

      expect do
        client.send(:handle_message, { 'id' => 'unknown-id', 'result' => { 'status' => 'success' } })
      end.not_to raise_error

      expect(client.instance_variable_get(:@requests)[known_id]).to eq(:pending)
    end

    it 'handles duplicate response id idempotently' do
      connection = instance_double(Faye::WebSocket::Client)
      allow(connection).to receive(:send)

      client.instance_variable_set(:@connection, connection)
      id = client.request('ping')

      client.send(:handle_message, { 'id' => id, 'result' => { 'status' => 'success' } })

      expect do
        client.send(:handle_message, { 'id' => id, 'result' => { 'status' => 'success' } })
      end.not_to raise_error

      expect(client.instance_variable_get(:@requests)).not_to have_key(id)
    end
  end

  describe 'Account & Ledger public API wrappers' do
    shared_examples 'request wrapper' do |wrapper_method, command, params|
      it "delegates ##{wrapper_method} to request with #{command} command and returns its value" do
        sentinel = "#{wrapper_method}-id"
        expect(client).to receive(:request).with(command, **params).and_return(sentinel)

        expect(client.public_send(wrapper_method, **params)).to eq(sentinel)
      end
    end

    include_examples 'request wrapper', :account_channels, 'account_channels', { account: 'rAccount', destination_account: 'rDest' }
    include_examples 'request wrapper', :account_currencies, 'account_currencies', { account: 'rAccount', strict: true }
    include_examples 'request wrapper', :account_info, 'account_info', { account: 'rAccount', ledger_index: 'validated' }
    include_examples 'request wrapper', :account_lines, 'account_lines', { account: 'rAccount', peer: 'rPeer' }
    include_examples 'request wrapper', :account_nfts, 'account_nfts', { account: 'rAccount', limit: 10 }
    include_examples 'request wrapper', :account_objects, 'account_objects', { account: 'rAccount', type: 'offer' }
    include_examples 'request wrapper', :account_offers, 'account_offers', { account: 'rAccount', ledger_index: 'current' }
    include_examples 'request wrapper', :account_tx, 'account_tx', { account: 'rAccount', ledger_index_min: -1, ledger_index_max: -1, limit: 5 }
    include_examples 'request wrapper', :gateway_balances, 'gateway_balances', { account: 'rIssuer', hotwallet: ['rHotWallet'] }
    include_examples 'request wrapper', :noripple_check, 'noripple_check', { account: 'rAccount', role: 'gateway', transactions: true }
    include_examples 'request wrapper', :ledger, 'ledger', { ledger_index: 'validated', transactions: false }
    include_examples 'request wrapper', :ledger_closed, 'ledger_closed', {}
    include_examples 'request wrapper', :ledger_current, 'ledger_current', {}
    include_examples 'request wrapper', :ledger_data, 'ledger_data', { ledger_index: 'validated', limit: 2 }
    include_examples 'request wrapper', :ledger_entry, 'ledger_entry', { ledger_index: 'validated', offer: { account: 'rAccount', seq: 1 } }
  end

  describe 'response helper wrappers' do
    it 'delegates account_info_response to request_with_retry and returns its value' do
      response = { 'id' => 'info-id', 'result' => { 'status' => 'success' } }
      expect(client).to receive(:request_with_retry).and_return(response)

      expect(client.account_info_response(account: 'rAccount')).to eq(response)
    end

    it 'delegates account_tx_response to request_with_retry and returns its value' do
      response = { 'id' => 'tx-id', 'result' => { 'status' => 'success' } }
      expect(client).to receive(:request_with_retry).and_return(response)

      expect(client.account_tx_response(account: 'rAccount')).to eq(response)
    end
  end
end