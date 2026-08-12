# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.1] - 2026-08-12

### Added
- CI matrix now covers Ruby 3.2, 3.3, 3.4 and (experimental) 4.0.

### Changed
- Raised minimum Ruby to **3.2**; dropped end-of-life 3.0 and 3.1 from the support matrix.

### Fixed
- **Ruby 3.4 / 4.0 compatibility**: declare `bigdecimal` as an explicit runtime dependency.
  It was removed from Ruby's default gems in 3.4, which broke `require 'bigdecimal'` in the
  binary codec on Ruby 3.4 and 4.0.

## [0.6.0] - 2026-08-05

### Added
- **Connection readiness**: `Client#connect!` (and `connect(wait: true)`) block until the
  WebSocket connection is open; `#open?` and `#wait_until_open` expose the state, so requests
  no longer race with connection setup.
- **Faucet helper**: `XRPL.fund_wallet(client)` / `XRPL::Faucet` creates and funds a wallet on
  the Testnet and waits until the account is funded on the ledger.
- **Transaction lifecycle** on the client (client-centric design): `Client#autofill`,
  `Client#submit`, and `Client#submit_and_wait` (reliable submission that polls until the
  transaction is included in a validated ledger).
- **Optional logger**: `Client.new(url, logger:)` — the library is silent by default and only
  emits diagnostics through an injected logger.
- Example scripts for funding a wallet, querying account info, and sending a payment.

### Changed
- The library no longer writes to `stdout` on its own; connection messages go through the
  optional logger instead.

## [0.5.2]

### Added
- Binary codec, address codec, key pairs (secp256k1 / ed25519), wallet, and a WebSocket
  client with account and ledger public API wrappers.
