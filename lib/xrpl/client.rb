# frozen_string_literal: true

require 'eventmachine'
require 'faye/websocket'
require 'json'
require 'securerandom'

module XRPL
  class Client
    attr_reader :url, :connection

    def initialize(url)
      @url = url
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
      payload = {
        id: id,
        command: command
      }.merge(params)

      send_message(payload)
      # TODO: Implement promise/future or callback for response
      id
    end

    def subscribe(**params)
      request('subscribe', **params)
    end

    def unsubscribe(**params)
      request('unsubscribe', **params)
    end

    private

    def send_message(payload)
      raise "Not connected" unless @connection
      @connection.send(payload.to_json)
    end

    def handle_message(message)
      # TODO: Route message to appropriate request handler or event listener
      if message['id'] && @requests[message['id']]
        # handle response
      end
    end
  end
end
