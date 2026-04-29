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
end