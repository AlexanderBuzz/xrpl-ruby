# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.2] - 2026-11-09

A patch release with one codec fix: an account field of length zero now keeps
its bytes through decoding and encoding, as in rippled. The README's advice on
`PaymentBurn` is updated too. Codec fixtures 39/39 and 263/263, both ways; all
10 Testnet specs pass on the release commit.

### Changed

- **`PaymentBurn` delegation.** The README no longer advises against it on
  Mainnet and Testnet, where `fixCleanup3_4_0` is now enabled. On a network
  without the amendment the warning still applies.

### Fixed

- **An unset account field.** An account field of length zero, as in a pseudo
  transaction, decoded as the zero account and encoded back as 20 zero bytes,
  which changes the bytes and the hash. Both directions now follow rippled's
  `STAccount`: an empty field reads as `''`, and `''` writes an empty field.
  The zero account `rrrrrrrrrrrrrrrrrrrrrhoLvTp` and accounts in fixed-width
  positions (an issuer, a path step) are unchanged. If you passed `''` to mean
  the zero account, pass `rrrrrrrrrrrrrrrrrrrrrhoLvTp` instead.

## [0.9.1] - 2026-11-02

A patch release with one fix: codec types now produce valid JSON inside
`JSON.generate`, which before gave invalid JSON or raised. Nothing else
changes; the codec's own calls behave as in 0.9.0. Codec fixtures 39/39
and 263/263, both ways; all 10 Testnet specs pass on the release commit.

### Fixed

- **Codec types work inside `JSON.generate`.** Every type answered Ruby's
  JSON library the way it answers the codec: with the value, not with JSON
  text. As a result `JSON.generate({ 'x' => obj })`
  - gave invalid JSON for a Uint64 or AccountId (`{"x":00000000000036D6}`),
  - raised `TypeError` for a Uint32 or an STObject.

  Called with a `JSON::State`, which is what `JSON.generate`,
  `pretty_generate` and `dump` pass, `to_json` now renders the codec value as
  JSON. Every other call is unchanged, so the codec's own
  `to_json(definitions, field_name)` still returns the value. For encoders
  that ask for `as_json` instead (ActiveSupport), the types answer with the
  codec value as well.

## [0.9.0] - 2026-11-02

Batch (XLS-56) and permission delegation (XLS-75), both enabled on Mainnet
since October, are fully supported now:
- `autofill` prepares and prices a Batch.
- Accounts sign their part with `Wallet#sign_batch`.
- `Wallet.combine_batch_signers` merges the parts.
- Delegated transactions are proven on the Testnet.

All Testnet specs pass on the release commit: a Batch of one account, a swap
between two accounts, a signer list, tickets, and delegation with and
without permission.

The codec now also reads UInt Strings the way rippled 3.4.1 does, which is
the one breaking change. It fixes a serialisation bug that could make a
multisigned transaction invalid: about one `Signers` entry in 256 lost its
end marker. Codec fixtures are unchanged: 39/39 transactions and 263/263
ledger entries, both directions.

### Breaking

- **UInt Strings are read the way rippled reads them.** rippled 3.4.1
  (`STParsedJSON`) and ripple-binary-codec read these field types like this:
  - **UInt8, UInt16, UInt32:** a whole decimal number.
  - **UInt64:** hex of any length, except in the base-10 fields
    (`MPTAmount`, `MaximumAmount`, `OutstandingAmount`, `LockedAmount`,
    `ConfidentialOutstandingAmount`), which are decimal.
  - **Int32, Int64:** a signed decimal number.

  A leading `+` is accepted where rippled accepts it (UInt32, Int32,
  Int64), not for UInt8, UInt16 or UInt64.

  This codec differed in two places, and both now follow rippled:
  - A UInt8/16/32 String in its full width was read as hex. `"00000065"`
    as a `Sequence` was 101 here and is 65 in rippled; `"0000000A"` was 10
    and now raises.
  - An unpadded UInt64 String was read as decimal. `"100"` as `IndexNext`
    was 100 and is `0x100` in rippled; `"36d6"` was 36.

  Names count only for their own field: `TransactionType` and
  `LedgerEntryType` take type names, `TransactionResult` result codes,
  `PermissionValue` permission names. Before, any field of the same width
  took them, so `TicketSequence: "TrustSet"` was ticket 21 and
  `TransferFee: "Payment"` was 0.

  Integers and the names in their own fields are unchanged, as is everything
  the codec decodes: it renders UInt8/16/32 as Integers and UInt64 as 16 hex
  digits, which round-trips. Affected is only code that passes
  - UInt8/16/32 values as hex Strings,
  - unpadded UInt64 values meant as decimal, or
  - a name in a field it does not belong to, such as
    `TicketSequence: "TrustSet"` or `TransferFee: "Payment"`, which now
    raises, or
  - an Int64 as a hex String: `Int64.from("DEAD")` was 57005 and now raises.
    Int64 also decodes to a decimal String (`"-9"`) instead of 16 hex digits
    (`"FFFFFFFFFFFFFFF7"`), so it round-trips. rippled 3.4.1 has no Int64
    field, so this concerns direct use of the type only.

  Where ripple-binary-codec accepts a value,
  `json_to_binary` now produces the same bytes; it also accepts decimal
  UInt8/16 Strings, which rippled reads and ripple-binary-codec refuses.

### Added

- **Permission delegation is verified on the Testnet** (XLS-75,
  PermissionDelegationV1_1 enabled on Mainnet since 2026-10-08). The library
  needed no change:
  - `Wallet#sign` signs a transaction whose `Account` is another account.
  - `autofill` takes the `Sequence` from `Account`.
  - The codec translates `PermissionValue` names (since 0.8.0).

  `spec/integration/xrpl/delegation_spec.rb` covers the whole flow:
  - a `DelegateSet`,
  - then a `Payment` with `Delegate`, signed by the delegate,
  - checked against rippled 3.4.1: the account pays the amount and the
    delegate pays the fee,
  - and a delegate without the permission is refused with
    `terNO_DELEGATE_PERMISSION`.

  The README has a section on it, including the warning from xrpl.org not to
  delegate `PaymentBurn` before `fixCleanup3_4_0` is enabled.
- **Batch signing across accounts.** `Wallet#sign_batch` produces the
  `BatchSigners` entry for an account with inner transactions in the Batch:
  the wallet's own account, another account it is the regular key of
  (`batch_account:`), or one signer of a signer list (`multisign:`). For a
  delegated inner transaction the `Delegate` signs.
  `Wallet.combine_batch_signers` merges the signed copies, given as Hashes
  or hex. It sorts the entries by numeric AccountID, drops the outer
  account's entry, and merges signatures from one signer list into a single
  entry. It refuses copies of different Batches and an outer transaction that
  is already signed.
  `BinaryCodec.signing_batch_data` builds the payload rippled 3.4.1 verifies:
  `BCH\0`, the outer account, the sequence value (the `TicketSequence` when
  `Sequence` is 0), Flags, the inner transaction IDs and the signer accounts.
  Signatures match the xrpl.js vectors byte for byte, and a swap between two
  accounts validates on the Testnet. `examples/batch.rb` shows both flows.
- **`BinaryCodec.transaction_id`** gives the ID of any transaction, signed or
  unsigned (SHA512Half of `TXN\0` and its serialisation), and
  `BinaryCodec.inner_transaction_ids` the IDs of a Batch's inner
  transactions. `Wallet#sign` uses it for its `hash`.
- **`autofill` prepares a Batch** (XLS-56, BatchV1_1 enabled on Mainnet
  since 2026-10-09). Every inner transaction gets `tfInnerBatchTxn`, `Fee`
  `"0"` and an empty `SigningPubKey`; sequences follow `autofillBatchTxn` in
  xrpl.js: the outer account's inner transactions continue after the outer
  `Sequence`, every other account starts at its own, a given `Sequence` or
  `TicketSequence` is kept, and the account's following inner transactions
  continue after an explicit `Sequence` (xrpl.js hands it out a second time). What the ledger would refuse raises
  `ArgumentError` before anything is signed: not exactly one mode flag,
  fewer than two or more than eight inner transactions, an entry that is not
  a `RawTransaction` wrapper, a nested Batch, an inner signature, fee or key.
  The rules live in `XRPL::Batch`, which needs no network.

### Fixed

- **A Sequence next to a TicketSequence is refused in a Batch.** On a ticket
  `Sequence` is 0, and rippled refuses anything else (`temSEQ_AND_TICKET`).
  `autofill` kept a nonzero one on an inner transaction and counted it, so
  the account's later inner transactions got sequences that were too high.
  It now raises `ArgumentError` before handing out any sequence, for the
  outer transaction as well as the inner ones. Every inner transaction is
  checked before the first sequence is fetched. A `Sequence` given as a
  String is read the way the codec encodes it, also in the BatchSigner
  payload, rather than with `#to_i`; a name or a malformed String raises.
- **`autofill` gives a transaction on a ticket `Sequence` 0.** With a
  `TicketSequence` and no `Sequence`, it fetched the account's sequence,
  which rippled refuses next to a ticket. This affected every transaction
  type, not only a Batch.
- **Batch sequences around tickets.** Two cases of `autofill` were wrong
  for a Batch:
  - An inner transaction on a ticket got no `Sequence`. The field is
    required and is 0 on a ticket, and rippled refuses the Batch without it.
  - An inner `TicketCreate` did not reserve the sequences of the tickets it
    creates, so the next inner transaction of that account repeated one of
    them.

  Both now follow rippled: a transaction on a ticket consumes no sequence,
  and a `TicketCreate` takes one per ticket after its own, or from the
  current sequence when it is itself on a ticket. Found through the Testnet
  tests of xrpl-php, which fixed the first case the same day.
- **A Batch over several accounts was charged too little.** The fee is
  `(2 + n) × base fee` plus the inner fees (XLS-56 §2.2), with n the
  signatures in `BatchSigners`; 0.8.0 left n out unless it came in as
  `signers_count:`. `Fee.calculate` now counts `BatchSigners` itself, a
  signer-list entry by its nested `Signers`. Because the signatures cover
  the finished Batch, its fee is set before they exist:
  `autofill(batch, batch_signatures: 2)` says how many will come. It is a
  keyword, not a field, so it never reaches the codec. The 2 XRP cap applies
  to a Batch as it does in xrpl.js.

- **An STArray element could lose its ObjectEndMarker on encode.** The
  codec closed an element with `0xE1` only when its last byte was not
  already `0xE1`, so the marker went missing whenever an element ended in
  that byte by chance: a `Signer` or `RawTransaction` whose last AccountID
  ends in `0xE1` (about one address in 256), a `Memo` whose data does, or an
  element ending in a nested object (`AffectedNodes`). Such a transaction
  was serialised, and therefore signed, differently from rippled and was
  rejected. Every element now gets its marker; the binaries match
  ripple-binary-codec byte for byte. The codec fixtures contain no such
  element, which is why they never showed it.
- **Decoding wrote a nested object's end marker twice** when re-serialising
  it, which surfaced as stray `ArrayEndMarker` / `ObjectEndMarker` keys in
  decoded metadata.

### Changed

- **UInt fields refuse malformed values.** A String that is not a number in
  the field's reading (see Breaking) raises `ArgumentError`. Before, it went
  through `#to_i`:
  - `"101junk"` became 101, `"12.5"` became 12.
  - `"abc"`, `"-1"` and `"0x10"` became 0.

  A number outside the field's range also raises now. Before, `2**32` as a
  UInt32 came out five bytes long, and a negative number became 0.
- **`STObject.from_parser` raises on malformed input** instead of ending
  the object silently. The last `rescue => e; break` of the codec is gone;
  a truncated blob used to decode into a partial object.

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
