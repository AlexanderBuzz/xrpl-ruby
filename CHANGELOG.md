# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
