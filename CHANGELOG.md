# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.0] - 2026-08-26

The binary codec now passes the full ripple-binary-codec reference fixture set
(287 cases, both directions). It previously passed none of them on decode: the
fixtures had been vendored in `spec/binary-codec/fixtures/` for a long time
without any spec loading them, so the suite reported green while decoding
0 of 261 ledger objects.

### Breaking

- **`binary_to_json` returns different types.** UInt8/16/32 fields come back as
  numbers instead of zero-padded hex strings (`Sequence` is `1`, not
  `"00000001"`), and native XRP amounts come back as strings instead of
  integers (`Balance` is `"370000000"`, not `370000000`). This is what rippled
  itself returns; the previous output matched no implementation.
- **`STObject#to_json` returns a Hash**, not a JSON string. The string return
  forced every nested value through a parse on the way out, which is what
  turned native amounts into integers.
- **Malformed input raises.** `STObject#to_json` and `STArray#to_json` caught
  every parser error and returned a partially decoded object. A codec that
  silently drops fields is worse than one that fails, so the rescues are gone.
- `tecHOOK_REJECTED` is no longer a known transaction result. It is a Xahau
  code and never belonged in the XRP Ledger definitions.

### Added

- **Transaction models** — `XRPL::Transaction::Payment`, `::EscrowCreate` and
  80 more, generated at load time from `TRANSACTION_FORMATS` so they cannot
  drift from the definitions. Fields are written in snake_case and stored under
  the ledger's own names; `#validate!` reports missing required fields before a
  round trip is spent, and each type carries its flags as constants
  (`Payment::TF_PARTIAL_PAYMENT`). A plain Hash still works everywhere a
  transaction is accepted.
- **`BinaryCodec::Number`** — the STNumber type (12 bytes: int64 mantissa,
  int32 exponent). 17 serialised fields reference it — the Vault and Lending
  Protocol amounts — and no class existed, so those fields could not be
  encoded at all. The gap predates this release.
- **`Issue` supports MPT** (`mpt_issuance_id`), in both directions.
- **Conformance spec** running `codec-fixtures.json`, and a definitions spec
  that checks every type a serialised field uses resolves to a class.

### Changed

- **`definitions.json` synced verbatim with XRPLF.** FIELDS 343 → 381,
  TRANSACTION_TYPES 76 → 83, LEDGER_ENTRY_TYPES 31 → 32, TRANSACTION_RESULTS
  189 → 195. Adds the Sponsorship and Confidential MPT fields and transactions,
  `TakerGetsMPT`, `TakerPaysMPT` and `ReferenceHolding`. Renames `UInt384`/
  `UInt512` to `Hash384`/`Hash512` and `MutableFlags` to `ImmutableFlags`; the
  type map keeps the old names resolving.
- `Client#autofill`, `#submit` and `#submit_and_wait` accept a transaction
  model as well as a Hash.
- The gemspec packages everything under `lib/`, not only the `.rb` files. Data
  files previously needed an entry of their own, and a forgotten one would have
  broken the installed gem while every local run stayed green, because the
  working copy has the file either way. `spec/packaging_spec.rb` checks it now.

### Fixed

- **`Issue` read a fixed 40 bytes.** An XRP issue is 20, so the rest came out
  of the following field: `Asset` and `Asset2` decoded as `nil` and
  `IssuingChainDoor` as the zero account.
- **`STArray.from_parser` dropped the ArrayEndMarker** it is meant to restore.
  The reconstructed bytes had no terminator, so re-parsing them ran the array
  on into the fields that followed — `AMMBid` lost `Asset` and `Asset2` into
  `AuthAccounts`.
- **`Currency#to_json` took no arguments** while every type is called as
  `to_json(definitions, field_name)`. It raised `ArgumentError` for every
  nested Currency field, which the silent rescue then swallowed — that is how
  `BaseAsset` and `QuoteAsset` disappeared from `PriceDataSeries`.
- **`XChainBridge` omitted the `0x14` length prefix** before each account,
  which is why all eight XChain fixtures failed to serialise.
- **A zero IOU rendered as `"-0"`** instead of `"0"`.

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
