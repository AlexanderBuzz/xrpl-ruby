# XRPL-Ruby

[![CI](https://github.com/AlexanderBuzz/xrpl-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/AlexanderBuzz/xrpl-ruby/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/AlexanderBuzz/xrpl-ruby/branch/main/graph/badge.svg)](https://codecov.io/gh/AlexanderBuzz/xrpl-ruby)
[![Gem Version](https://badge.fury.io/rb/xrpl-ruby.svg)](https://rubygems.org/gems/xrpl-ruby)
[![Downloads](https://img.shields.io/gem/dt/xrpl-ruby)](https://rubygems.org/gems/xrpl-ruby)
[![Ruby](https://img.shields.io/badge/ruby->=_3.0-CC342D?logo=ruby&logoColor=white)](https://www.ruby-lang.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

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

## Transactions

A transaction can always be a plain Hash, as above. The transaction classes
are an addition on top of that: they are generated from the field formats in
`definitions.json`, so they know which fields a type accepts, which of them
are required, and what its flags are called.

```ruby
payment = XRPL::Transaction::Payment.new(
  account:     wallet.classic_address,
  destination: receiver.classic_address,
  amount:      '1000000',
  flags:       XRPL::Transaction::Payment::TF_PARTIAL_PAYMENT
)

payment.validate!   # raises before a round trip is spent
client.submit_and_wait(payment, wallet: wallet)
```

Fields are written in snake_case and stored under the ledger's own names, so
`#to_h` produces exactly what the binary codec expects:

```ruby
payment.to_h
# => {"TransactionType"=>"Payment", "Account"=>"r...", "Destination"=>"r...",
#     "Amount"=>"1000000", "Flags"=>131072}
```

A field the type does not define is rejected when it is set, rather than by
the server several seconds later:

```ruby
payment.limit_amount = {}   # NoMethodError
XRPL::Transaction::Payment.new(limit_amount: {})
# => XRPL::Transaction::ValidationError: Payment has no field LimitAmount
```

`XRPL::Transaction.from(hash)` builds the matching class from a transaction
hash, which is useful for anything read back off the ledger. Note that
`validate!` follows rippled's formats: it checks what the ledger requires for
serialisation, which is not always what a transaction needs to be meaningful.

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
