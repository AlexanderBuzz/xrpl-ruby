# frozen_string_literal: true

# Batch signing (XLS-56) against xrpl.js.
#
# The Batch, the wallets and every expected signature are those of
# packages/xrpl/test/wallet/batchSigner.test.ts in xrpl.js; the payload bytes
# and the inner transaction IDs were produced with xrpl 5.3.0 and
# ripple-binary-codec 2.11.0, and xrpl-php checks the same values. secp256k1
# signatures are deterministic (RFC 6979) and Ed25519 ones always, so they
# compare byte for byte. The payload layout is rippled 3.4.1's
# (serializeBatch plus STTx::checkBatchSingleSign / checkBatchMultiSign).
#
# xrpl.js derives one wallet from a secp256k1 seed with Ed25519 forced; it is
# built from the Ed25519 key pair directly here.
RSpec.describe 'Batch signing' do
  seed = 'spkcsko6Ag3RbCSVXV2FJ8Pd4Zac1'
  submit_seed = 'sEd7HmQFsoyj5TAm6d98gytM9LJA1MF'
  regkey_seed = 'sEdStM1pngFcLQqVfH3RQcg2Qr6ov9e'

  outer = 'rJCxK2hX9tDMzbnn3cg1GU2g19Kfmhzxkp' # its AccountID ends in 0xE1
  ed = 'rJy554HmWFFJQGnRfZuoo8nV97XSMq77h7'
  secp = 'rPMh7Pi9ct699iZUTWaytJUoHcJ7cgyziK'
  regkey = 'rwRNeznwHzdfYeKWpevYmax2NSDioyeEtT'

  inner_ids = %w[
    FCCBD0F8F72050FE0CFC7AC5686EBDE93A8AAFFF5C60BA22957099DF484BD6CA
    9EDF5DB29F536DD3919037F1E8A72B040D075571A10C9000294C57B5ECEEA791
  ]
  payload_prefix = '42434800' \
                   'C1D81FB31C42392BA1570431F1CBCBEEBBEF50E1' \
                   '00000000' \
                   '00000001' \
                   '00000002' + inner_ids.join

  let(:secp_wallet) { Wallet::Wallet.from_seed(seed) }
  let(:ed_wallet) do
    keys = KeyPairs::Ed25519.derive_key_pair(AddressCodec::AddressCodec.new.decode_seed(seed)[:bytes])
    Wallet::Wallet.new(keys[:public_key], keys[:private_key])
  end
  let(:regkey_wallet) { Wallet::Wallet.from_seed(regkey_seed) }
  let(:outer_wallet) { Wallet::Wallet.from_seed(submit_seed) }

  let(:batch) do
    {
      'Account' => outer, 'Flags' => 1, 'TransactionType' => 'Batch',
      'RawTransactions' => [
        { 'RawTransaction' => { 'Account' => ed, 'Flags' => 0x40000000, 'Amount' => '5000000',
                                'Destination' => secp, 'Fee' => '0', 'Sequence' => 215,
                                'SigningPubKey' => '', 'TransactionType' => 'Payment' } },
        { 'RawTransaction' => { 'Account' => secp, 'Flags' => 0x40000000, 'Amount' => '1000000',
                                'Destination' => outer, 'Fee' => '0', 'Sequence' => 470,
                                'SigningPubKey' => '', 'TransactionType' => 'Payment' } }
      ]
    }
  end
  # The Batch of xrpl.js's combineBatchSigners tests.
  let(:sequenced) { batch.merge('Flags' => 0x10000, 'Sequence' => 215, 'LastLedgerSequence' => 14_973, 'NetworkID' => 21_336) }

  def entry(signed)
    signed['BatchSigners'].first['BatchSigner']
  end

  it 'uses the wallets of xrpl.js' do
    expect([secp_wallet, ed_wallet, regkey_wallet, outer_wallet].map(&:classic_address))
      .to eq([secp, ed, regkey, outer])
  end

  describe 'the codec' do
    it 'gives the inner transactions their unsigned IDs' do
      expect(BinaryCodec.inner_transaction_ids(batch)).to eq(inner_ids)
      expect(BinaryCodec.transaction_id(batch['RawTransactions'][0]['RawTransaction'])).to eq(inner_ids[0])
    end

    it 'builds the payload rippled verifies' do
      single = BinaryCodec.signing_batch_data(batch, batch_account: secp)
      multi = BinaryCodec.signing_batch_data(batch, batch_account: ed, signer_account: regkey)

      expect(bytes_to_hex(single)).to eq("#{payload_prefix}F51DFC2A09D62CBBA1DFBDD4691DAC96AD98B90F")
      expect(bytes_to_hex(multi)).to eq("#{payload_prefix}C53440AC6F65A0CF326B76E0EE81D9B4D7A22C5F" \
                                        '674E837FE8BE47B63BC2040626100FA3F071AF6A')
    end

    it 'uses the TicketSequence as the sequence value when Sequence is 0' do
      ticketed = batch.merge('Sequence' => 0, 'TicketSequence' => 777, 'Flags' => 0x10000)

      expect(BinaryCodec.batch_sequence_value(ticketed)).to eq(777)
      expect(BinaryCodec.batch_sequence_value('Sequence' => 215, 'TicketSequence' => 9)).to eq(215)
      expect(BinaryCodec.batch_sequence_value({})).to eq(0)
      expect(bytes_to_hex(BinaryCodec.signing_batch_data(ticketed, batch_account: secp)))
        .to start_with('42434800C1D81FB31C42392BA1570431F1CBCBEEBBEF50E1' '00000309' '00010000')
      expect(entry(secp_wallet.sign_batch(ticketed))['TxnSignature'])
        .to eq('3045022100DAE7E156F64899D27EB1464730110F66464458EF873E006A2A781E4F998D1CB8' \
               '02200B5D52C2B87CC9E7C67E28237C205DC96A24477DB37BF34E7D4F8383D0A35272')
    end

    it 'refuses an entry of RawTransactions that is not a RawTransaction wrapper' do
      bare = batch.merge('RawTransactions' => [batch['RawTransactions'][0], batch['RawTransactions'][1]['RawTransaction']])

      expect { BinaryCodec.inner_transaction_ids(bare) }.to raise_error(ArgumentError, /needs a RawTransaction/)
      expect { BinaryCodec.inner_transaction_ids('RawTransactions' => ['x']) }
        .to raise_error(ArgumentError, /needs a RawTransaction/)
    end

    # What is signed has to agree with what is serialised: the codec encodes
    # the String "000000D7" as 215, so the payload carries 215 too.
    it 'puts the sequence value into the payload as the codec encodes it' do
      as_string = sequenced.merge('Sequence' => '000000D7')

      expect(BinaryCodec.batch_sequence_value(as_string)).to eq(215)
      expect(BinaryCodec.signing_batch_data(as_string, batch_account: secp))
        .to eq(BinaryCodec.signing_batch_data(sequenced, batch_account: secp))
    end

    it 'refuses a Batch without Account or Flags' do
      expect { BinaryCodec.signing_batch_data(batch.except('Flags'), batch_account: secp) }
        .to raise_error(ArgumentError, /Account and Flags/)
    end
  end

  # xrpl.js signs these over a Batch without a Sequence, so its sequence
  # value is 0. sign_batch refuses such a Batch (see below), so the vectors
  # are checked on what sign_batch is made of: the payload and the key.
  describe 'the xrpl.js signatures' do
    def signature(wallet, batch_account, signer_account = nil)
      wallet.sign(bytes_to_hex(BinaryCodec.signing_batch_data(batch, batch_account: batch_account,
                                                                     signer_account: signer_account)))
    end

    it 'match with secp256k1, Ed25519 and a regular key' do
      expect(signature(secp_wallet, secp))
        .to eq('304502210098890858AA57D6515D7C523FE076FA97BFA87DA666A87B4A7CF44249181DC1DC' \
               '02201B90E513FE2F45D41FB31850F463C0ECBA8F5126B1AF431B67C4004CA0DD8042')
      expect(signature(ed_wallet, ed))
        .to eq('27B496F0C1F2C4789A0E6CF25265069980190C786053CF5D6C066C07E21D632A' \
               '6EB87C56275109A8542EEDE782FDC5591EA51FAF28C3FCFCF35BCE960F1D8601')
      expect(signature(regkey_wallet, ed))
        .to eq('046315C731DF089E08EB6662251F12B22938ED462F66BC561A847A87DF6B3C9A' \
               'C811D9EC5971EDEC2BA96C959BDE883CD838B7EF6460A47AD9B71518F1A2A00B')
    end

    it 'match when multisigning, as itself and as another signer account' do
      expect(signature(regkey_wallet, ed, regkey))
        .to eq('8FCA6C1056C2146DC13F4D10BA297335A82F562D837FA3C65D75DCDC87540F61' \
               '428B7370FCC1DE4D83B6FA1A00A18CD9283E7B08089091ED84CC3E4A8B43F00F')
      expect(signature(regkey_wallet, ed, outer))
        .to eq('D80D4195BF67D5CB12CA225D04DA4D00AC77250803671E09DF61F1695A831FAD' \
               '6BF820F335DD2D8CFE16DA55CFC2E64AEC8A1429524E6CDB6C36B7AEA717C700')
    end
  end

  describe 'Wallet#sign_batch' do
    def payload(batch_account, signer_account = nil)
      bytes_to_hex(BinaryCodec.signing_batch_data(sequenced, batch_account: batch_account,
                                                             signer_account: signer_account))
    end

    it 'adds the BatchSigner entry and leaves the inner transactions untouched' do
      signed = secp_wallet.sign_batch(sequenced)

      expect(signed['BatchSigners']).to eq([{ 'BatchSigner' => {
        'Account' => secp,
        'SigningPubKey' => '02691AC5AE1C4C333AE5DF8A93BDC495F0EEBFC6DB0DA7EB6EF808F3AFC006E3FE',
        'TxnSignature' => secp_wallet.sign(payload(secp))
      } }])
      expect(signed.except('BatchSigners')).to eq(sequenced)
    end

    it 'signs like xrpl.js with Ed25519 over a Batch with a Sequence' do
      expect(entry(ed_wallet.sign_batch(sequenced))).to include(
        'Account' => ed,
        'TxnSignature' => '93BC0B856D4A5A8C51955BF2C9D33BD06B67D8EC3569A7A8290E0D14F5AE2882' \
                          'B86DA9F79B07C878D976FD0D376852407936B79B8BCB8840903675C853EE7205'
      )
    end

    it 'signs for another account with its regular key' do
      expect(entry(regkey_wallet.sign_batch(sequenced, batch_account: ed))).to eq(
        'Account' => ed,
        'SigningPubKey' => 'ED37D3F048B7F1E680B0A97F70C7843160B9F25D6398D07E68B9A2C83AA8E1B156',
        'TxnSignature' => regkey_wallet.sign(payload(ed))
      )
    end

    it 'multisigns as itself and as another signer account' do
      as_itself = entry(regkey_wallet.sign_batch(sequenced, batch_account: ed, multisign: true))
      as_outer = entry(regkey_wallet.sign_batch(sequenced, batch_account: ed, multisign: outer))

      expect(as_itself).to eq(
        'Account' => ed,
        'Signers' => [{ 'Signer' => {
          'Account' => regkey,
          'SigningPubKey' => 'ED37D3F048B7F1E680B0A97F70C7843160B9F25D6398D07E68B9A2C83AA8E1B156',
          'TxnSignature' => regkey_wallet.sign(payload(ed, regkey))
        } }]
      )
      expect(as_outer['Signers'][0]['Signer']).to include('Account' => outer,
                                                          'TxnSignature' => regkey_wallet.sign(payload(ed, outer)))
    end

    # rippled requires a Sequence; a signature over the value 0 matches no
    # Batch that can be submitted. The usual cause is signing before autofill.
    it 'refuses a Batch without a Sequence or TicketSequence' do
      expect { secp_wallet.sign_batch(batch) }.to raise_error(ArgumentError, /Sequence or TicketSequence/)
      expect { secp_wallet.sign_batch(batch.merge('Sequence' => 0)) }
        .to raise_error(ArgumentError, /Sequence or TicketSequence/)
    end

    it 'has the delegate sign for a delegated inner transaction' do
      delegated = Marshal.load(Marshal.dump(sequenced))
      delegated['RawTransactions'][0]['RawTransaction']['Delegate'] = regkey

      expect(Wallet::Wallet.batch_signer_accounts(batch)).to eq([ed, secp])
      expect(Wallet::Wallet.batch_signer_accounts(delegated)).to eq([regkey, secp])
      expect(entry(regkey_wallet.sign_batch(delegated))['Account']).to eq(regkey)
      expect { ed_wallet.sign_batch(delegated) }.to raise_error(ArgumentError, /no inner transaction/)
    end

    it 'refuses an account without an inner transaction' do
      expect { Wallet::Wallet.generate.sign_batch(sequenced) }.to raise_error(ArgumentError, /no inner transaction/)
    end

    it 'signs a transaction model the same as its Hash' do
      model = XRPL::Transaction::Batch.new(account: outer, flags: 0x10000, sequence: 215,
                                           last_ledger_sequence: 14_973, network_id: 21_336,
                                           raw_transactions: sequenced['RawTransactions'])

      expect(secp_wallet.sign_batch(model)).to eq(secp_wallet.sign_batch(sequenced))
      expect(Wallet::Wallet.batch_signer_accounts(model)).to eq([ed, secp])
    end

    it 'signs inner transaction models the same as their Hashes, and returns Hashes' do
      inner = sequenced['RawTransactions'][1]['RawTransaction']
      model = XRPL::Transaction::Payment.new(account: inner['Account'], destination: inner['Destination'],
                                             amount: inner['Amount'], fee: '0', signing_pub_key: '',
                                             sequence: inner['Sequence'], flags: inner['Flags'])
      with_model = sequenced.merge('RawTransactions' => [sequenced['RawTransactions'][0],
                                                         { 'RawTransaction' => model }])

      signed = secp_wallet.sign_batch(with_model)
      expect(signed).to eq(secp_wallet.sign_batch(sequenced))
      expect(BinaryCodec.inner_transaction_ids(with_model)).to eq(BinaryCodec.inner_transaction_ids(sequenced))
      expect { BinaryCodec.json_to_binary(signed) }.not_to raise_error
    end

    it 'refuses anything but a Batch' do
      expect { secp_wallet.sign_batch(sequenced['RawTransactions'][0]['RawTransaction']) }
        .to raise_error(ArgumentError, /needs a Batch/)
    end
  end

  describe 'Wallet.combine_batch_signers' do
    let(:by_secp) { secp_wallet.sign_batch(sequenced) }
    let(:by_ed) { ed_wallet.sign_batch(sequenced) }

    it 'combines the entries sorted by numeric AccountID' do
      expected = by_ed['BatchSigners'] + by_secp['BatchSigners']

      expect(Wallet::Wallet.combine_batch_signers([by_secp, by_ed])['BatchSigners']).to eq(expected)
      expect(Wallet::Wallet.combine_batch_signers([by_ed, by_secp])['BatchSigners']).to eq(expected)
      # rJy554... (C53440AC...) sorts before rPMh7P... (F51DFC2A...)
      expect(expected[0]['BatchSigner']['TxnSignature'])
        .to eq('93BC0B856D4A5A8C51955BF2C9D33BD06B67D8EC3569A7A8290E0D14F5AE2882' \
               'B86DA9F79B07C878D976FD0D376852407936B79B8BCB8840903675C853EE7205')
    end

    it 'combines serialised copies' do
      combined = Wallet::Wallet.combine_batch_signers([BinaryCodec.json_to_binary(by_secp),
                                                       BinaryCodec.json_to_binary(by_ed)])

      expect(combined['BatchSigners'].map { |e| e['BatchSigner']['Account'] }).to eq([ed, secp])
      expect(BinaryCodec.inner_transaction_ids(combined)).to eq(inner_ids)
    end

    it 'drops the outer account and duplicates' do
      with_outer = Marshal.load(Marshal.dump(sequenced))
      with_outer['RawTransactions'] << { 'RawTransaction' => {
        'Account' => outer, 'Flags' => 0x40000000, 'Amount' => '1000000', 'Destination' => secp,
        'Fee' => '0', 'Sequence' => 470, 'SigningPubKey' => '', 'TransactionType' => 'Payment'
      } }
      e = ed_wallet.sign_batch(with_outer)
      s = secp_wallet.sign_batch(with_outer)
      o = outer_wallet.sign_batch(with_outer)

      expect(Wallet::Wallet.combine_batch_signers([e, s, o, s])['BatchSigners'])
        .to eq(e['BatchSigners'] + s['BatchSigners'])
    end

    # xrpl-php #72, finding 8: several signatures of one signer list become
    # one entry with its Signers sorted.
    it 'merges the signer-list signatures of one account into one entry' do
      by_regkey = regkey_wallet.sign_batch(sequenced, batch_account: ed, multisign: true)
      by_outer_key = regkey_wallet.sign_batch(sequenced, batch_account: ed, multisign: outer)

      combined = Wallet::Wallet.combine_batch_signers([by_regkey, by_outer_key, by_secp])
      ed_entry = combined['BatchSigners'][0]['BatchSigner']

      expect(combined['BatchSigners'].size).to eq(2)
      expect(ed_entry['Account']).to eq(ed)
      # rwRNez... (674E837F...) sorts before rJCxK2... (C1D81FB3...)
      expect(ed_entry['Signers'].map { |s| s['Signer']['Account'] }).to eq([regkey, outer])
    end

    it 'refuses copies of different Batches' do
      other = ed_wallet.sign_batch(sequenced.merge('Flags' => 0x80000))

      expect { Wallet::Wallet.combine_batch_signers([by_secp, other]) }
        .to raise_error(ArgumentError, /have to be the same/)
    end

    it 'refuses a copy without BatchSigners and an outer transaction already signed' do
      expect { Wallet::Wallet.combine_batch_signers([by_secp, sequenced]) }
        .to raise_error(ArgumentError, /BatchSigners/)

      signed_outer = outer_wallet.sign(by_secp)['tx_blob']
      expect { Wallet::Wallet.combine_batch_signers([signed_outer, by_secp]) }
        .to raise_error(ArgumentError, /must not be signed/)
    end

    it 'refuses an empty list and a conflicting entry' do
      expect { Wallet::Wallet.combine_batch_signers([]) }.to raise_error(ArgumentError)

      forged = Marshal.load(Marshal.dump(by_secp))
      forged['BatchSigners'][0]['BatchSigner']['TxnSignature'] = '00'
      expect { Wallet::Wallet.combine_batch_signers([by_secp, forged]) }
        .to raise_error(ArgumentError, /Conflicting/)
    end

    it 'leaves a Batch the outer account signs and that decodes unchanged' do
      combined = Wallet::Wallet.combine_batch_signers([by_secp, by_ed]).merge('Fee' => '40')
      signed = outer_wallet.sign(combined)
      decoded = BinaryCodec.binary_to_json(signed['tx_blob'])

      expect(decoded.except('TxnSignature', 'SigningPubKey')).to eq(combined)
      expect(decoded['SigningPubKey']).to eq(outer_wallet.public_key)
      expect(signed['hash']).to eq(BinaryCodec.transaction_id(signed['tx_blob']))
    end
  end
end
