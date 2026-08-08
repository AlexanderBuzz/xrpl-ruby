# frozen_string_literal: true

require 'spec_helper'

RSpec.describe XRPL::Faucet do
  let(:client) { instance_double(XRPL::Client) }
  let(:wallet) { instance_double(Wallet::Wallet, classic_address: 'rTestAddressXXXXXXXXXXXXXXXXXXXXX') }
  let(:faucet) { described_class.new }

  let(:not_found) { { 'result' => { 'error' => 'actNotFound' } } }
  let(:funded)    { { 'result' => { 'account_data' => { 'Balance' => '100000000000' } } } }

  describe '#fund_wallet' do
    it 'requests funds and returns the wallet with its funded balance (in drops)' do
      allow(faucet).to receive(:http_post).and_return({})
      allow(client).to receive(:account_info_response).and_return(not_found, funded)

      result = faucet.fund_wallet(client, wallet, poll_interval: 0)

      expect(result[:wallet]).to eq(wallet)
      expect(result[:balance]).to eq(100_000_000_000)
    end

    it 'generates a new wallet when none is provided' do
      allow(Wallet::Wallet).to receive(:generate).and_return(wallet)
      allow(faucet).to receive(:http_post).and_return({})
      allow(client).to receive(:account_info_response).and_return(not_found, funded)

      result = faucet.fund_wallet(client, poll_interval: 0)

      expect(Wallet::Wallet).to have_received(:generate)
      expect(result[:wallet]).to eq(wallet)
    end

    it 'does not generate a wallet when one is supplied' do
      allow(faucet).to receive(:http_post).and_return({})
      allow(client).to receive(:account_info_response).and_return(funded)
      allow(Wallet::Wallet).to receive(:generate)

      faucet.fund_wallet(client, wallet, poll_interval: 0)

      expect(Wallet::Wallet).not_to have_received(:generate)
    end

    it 'POSTs the destination address to the faucet endpoint' do
      allow(client).to receive(:account_info_response).and_return(funded)
      expect(faucet).to receive(:http_post)
        .with(described_class::TESTNET_FAUCET, hash_including(destination: wallet.classic_address))
        .and_return({})

      faucet.fund_wallet(client, wallet, poll_interval: 0)
    end

    it 'raises FaucetError when the account is never funded within the timeout' do
      allow(faucet).to receive(:http_post).and_return({})
      allow(client).to receive(:account_info_response).and_return(not_found)

      expect { faucet.fund_wallet(client, wallet, timeout: 0.1, poll_interval: 0) }
        .to raise_error(XRPL::FaucetError, /not funded/)
    end

    it 'raises FaucetError when the faucet HTTP request fails' do
      allow(client).to receive(:account_info_response).and_return(not_found)
      allow(faucet).to receive(:http_post).and_raise(XRPL::FaucetError, 'Faucet request failed: 503 Service Unavailable')

      expect { faucet.fund_wallet(client, wallet, poll_interval: 0) }
        .to raise_error(XRPL::FaucetError, /Faucet request failed/)
    end
  end

  describe '.fund_wallet / XRPL.fund_wallet convenience' do
    it 'delegates to an instance' do
      allow_any_instance_of(described_class).to receive(:fund_wallet)
        .and_return(wallet: wallet, balance: 1)

      expect(XRPL.fund_wallet(client, wallet)).to eq(wallet: wallet, balance: 1)
    end
  end
end
