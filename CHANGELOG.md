# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.8.0] - 2026-09-24

The codec now targets **rippled 3.4.0** (released 2026-09-17) and passes the
ripple-binary-codec 2.11.0 fixture set: 39 transactions and 263 ledger
entries, both directions (302 cases; 287 before). Measured before the change:
transactions 38/39, accountState 262/263 decode.

### Breaking

- **`definitions.json` is rippled 3.4.0.** It is what a 3.4.0 node reports
  through `server_definitions` (s1.ripple.com), with the node's own digest in
  `hash`. FIELDS 381 → 357: the 27 `Hook*` fields plus `EmitGeneration` and
  `EmittedTxn` are gone, because rippled dropped Hooks; a blob carrying one
  of them no longer decodes. Added: `VaultKind`, `SubscriptionDate`,
  `RedemptionDate`, `LEVersion`, `ContractResult` (LendingProtocolV1_1,
  closed-ended vaults), and `CredentialIDs` on `VaultWithdraw` and
  `LoanBrokerCoverWithdraw`. ripple-binary-codec's `main` additionally
  carries four `*KeyEpoch` fields from rippled's development branch; they
  are in no release and deliberately not here.
- **`PermissionValue` decodes to its name.** A `DelegateSet` permission is
  a UInt32 that rippled renders by name: a transaction type as its code plus
  one (`"Payment"` = 1), the twelve granular permissions from 65537
  (`"TrustlineAuthorize"`). Encoding accepts the names; they were silently
  serialised as 0 before.

### Added

- **Ledger entry models** — `XRPL::LedgerEntry::AccountRoot`,
  `::RippleState`, `::Offer` and the other 28 types, generated from
  `LEDGER_ENTRY_FORMATS` the way the transaction models are generated from
  `TRANSACTION_FORMATS`. `XRPL::LedgerEntry.from(node)` builds the right
  class from anything `ledger_entry`, `account_objects` or `ledger_data`
  returns and keeps rippled's `index` alongside. Every `lsf` flag is a
  constant on its type. All 263 reference ledger entries round-trip through
  their model unchanged.
- **Flag helpers** on transactions and ledger entries: `#flag?` takes the
  ledger's name, the constant's name or the bit, `#flag_names` lists what
  is set.
- **Fees by transaction type.** `autofill` now charges what rippled charges:
  `EscrowFinish` pays for its `Fulfillment` (base × (33 + bytes / 16)),
  `AccountDelete`, `AMMCreate` and `VaultCreate` cost the owner reserve
  from `server_state`, a `Batch` pays two base fees plus those of its inner
  transactions, the confidential MPT transactions cost ten base fees, and
  multisigning adds one base fee per signature. Ordinary fees are capped at
  2 XRP (`Client.new(url, max_fee_drops:)`); the reserve-priced types are
  not. The rules are a pure module, `XRPL::Fee.calculate`, and the same
  ones xrpl.js applies. Before, every transaction paid the base fee, so an
  AccountDelete or an EscrowFinish with a fulfillment could not be
  autofilled.
- **Payment channel claims.** `Wallet#sign_payment_channel_claim(channel,
  drops)` and `#verify_payment_channel_claim`, plus
  `Wallet.verify_payment_channel_claim(..., public_key)` for the receiving
  side; `BinaryCodec.signing_claim_data` underneath. Checked against the
  xrpl.js signature vector byte for byte.
- The hash prefixes for batch, counterparty and sponsor signatures
  (`fixCleanup3_4_0`) are in `BinaryCodec::HASH_PREFIX`; the signing
  helpers for them are not written yet.
- `Definitions#delegatable_permissions`, and readers for the transaction
  type, ledger entry type and result tables the codec resolves names
  against.

### Changed

- `XRPL::Transaction` is built on a new `XRPL::Model` base shared with
  `XRPL::LedgerEntry`. Its public surface is unchanged;
  `Transaction::ValidationError` is now `Model::ValidationError`, reachable
  under both names. A model rejects a hash whose type field contradicts the
  class (`Payment.new('TransactionType' => 'TrustSet')`), where it used to
  keep the foreign value and serialise a TrustSet.
- The transaction models pick up the 3.4.0 fields without a code change:
  `VaultCreate.new(vault_kind:, subscription_date:, redemption_date:)`.
- A parity spec that pins `definitions.json` to the 3.4.0 digest and fails
  if a Hook or development-branch field comes back.

### Fixed

- `ConfidentialOutstandingAmount` renders in base 10 like the other MPToken
  amounts, not as a 16 digit hex string.
- `Definitions#get_field_instance` returns `nil` for an unknown field name.
  Serialising a hash with a foreign key now fails with "Field x is not
  defined" instead of a `NoMethodError` on `nil`.

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
