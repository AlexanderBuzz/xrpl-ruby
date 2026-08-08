# XRPL-Ruby

A pure-Ruby library to interact with the [XRP Ledger](https://xrpl.org) (XRPL) blockchain.

## Features

- Key and wallet management (secp256k1 and ed25519)
- Address codec and binary (transaction) codec
- WebSocket client for the XRP Ledger public API
- Testnet faucet helper to create and fund wallets
- Transaction lifecycle: autofill, sign, submit, and reliable "submit and wait"

## Requirements

- Ruby 3.0 or later

## Installation

Install the gem:

```sh
gem install xrpl-ruby
```

Or add it to your `Gemfile`:

```ruby
gem 'xrpl-ruby'
```

## Quick start

```ruby
require 'xrpl-ruby'

# 1. Connect to the Testnet (blocks until the connection is ready)
client = XRPL::Client.new(:testnet)
client.connect!

# 2. Create and fund a wallet using the Testnet faucet
wallet = XRPL.fund_wallet(client)[:wallet]
puts wallet.classic_address

# 3. Look up the account on the ledger
info = client.account_info_response(
  account: wallet.classic_address,
  ledger_index: 'validated'
)
puts info.dig('result', 'account_data', 'Balance')

# 4. Send 1 XRP (1,000,000 drops) and wait for validation
receiver = XRPL.fund_wallet(client)[:wallet]
payment = {
  'TransactionType' => 'Payment',
  'Account'         => wallet.classic_address,
  'Destination'     => receiver.classic_address,
  'Amount'          => '1000000'
}
result = client.submit_and_wait(payment, wallet: wallet)
puts result.dig('result', 'meta', 'TransactionResult') # => "tesSUCCESS"

client.disconnect
```

The client is silent by default. To see diagnostic output, pass a logger:

```ruby
require 'logger'
client = XRPL::Client.new(:testnet, logger: Logger.new($stdout))
```

More runnable examples are in the [`examples/`](examples) directory.

## Running the tests

```sh
bundle install
bundle exec rspec
```

Integration tests talk to the real Testnet and are skipped by default. Enable them explicitly:

```sh
XRPL_NETWORK=1 bundle exec rspec spec/integration
```

## Contributing

Bug reports and pull requests are welcome on GitHub at
<https://github.com/AlexanderBuzz/xrpl-ruby>.

## License

Released under the [MIT License](LICENSE).
