# frozen_string_literal: true

# The sequence rules are the ones xrpl.js applies in autofillBatchTxn; the
# refusals are what rippled's Batch preflight rejects (XLS-56).
RSpec.describe XRPL::Batch do
  let(:outer) { 'rOuterAccount' }
  let(:other) { 'rOtherAccount' }
  let(:sequences) { { other => 500 } }
  let(:fetched) { [] }
  let(:sequence_for) do
    lambda do |account|
      fetched << account
      sequences.fetch(account)
    end
  end

  def payment(account, extra = {})
    { 'RawTransaction' => { 'TransactionType' => 'Payment', 'Account' => account,
                            'Destination' => 'rDest', 'Amount' => '1000' }.merge(extra) }
  end

  def batch(*inner, flags: described_class::FLAGS['Batch']['tfAllOrNothing'], **extra)
    { 'TransactionType' => 'Batch', 'Account' => outer, 'Sequence' => 100, 'Flags' => flags,
      'RawTransactions' => inner }.merge(extra.transform_keys(&:to_s))
  end

  def prepare(tx)
    described_class.prepare(tx, sequence_for: sequence_for)
  end

  def inner(prepared)
    prepared['RawTransactions'].map { |wrapper| wrapper['RawTransaction'] }
  end

  it 'reads the flags from definitions.json' do
    expect(described_class::TF_INNER_BATCH_TXN).to eq(0x40000000)
    expect(described_class::MODE_FLAGS).to eq(0x10000 | 0x20000 | 0x40000 | 0x80000)
  end

  describe '.prepare' do
    it 'marks every inner transaction and empties its fee and key' do
      txs = inner(prepare(batch(payment(outer, 'Flags' => 0x20000), payment(outer))))

      expect(txs.map { |tx| tx['Flags'] }).to eq([0x40020000, 0x40000000])
      expect(txs.map { |tx| tx['Fee'] }).to eq(%w[0 0])
      expect(txs.map { |tx| tx['SigningPubKey'] }).to eq(['', ''])
    end

    it 'continues the outer account after the outer Sequence without asking the ledger' do
      txs = inner(prepare(batch(payment(outer), payment(outer))))

      expect(txs.map { |tx| tx['Sequence'] }).to eq([101, 102])
      expect(fetched).to be_empty
    end

    it 'starts every other account at its own sequence, once per account' do
      txs = inner(prepare(batch(payment(outer), payment(other), payment(other), payment(outer))))

      expect(txs.map { |tx| tx['Sequence'] }).to eq([101, 500, 501, 102])
      expect(fetched).to eq([other])
    end

    it 'asks the ledger for the outer account when the outer transaction uses a ticket' do
      sequences[outer] = 100
      txs = inner(prepare(batch(payment(outer), payment(outer), TicketSequence: 7)))

      expect(txs.map { |tx| tx['Sequence'] }).to eq([100, 101])
    end

    it 'keeps a given Sequence or TicketSequence' do
      txs = inner(prepare(batch(payment(outer, 'Sequence' => 300), payment(other, 'TicketSequence' => 9))))

      expect(txs.map { |tx| tx.values_at('Sequence', 'TicketSequence') }).to eq([[300, nil], [nil, 9]])
      expect(fetched).to be_empty
    end

    it 'accepts a Fee of "0", an empty key and transaction models' do
      model = XRPL::Transaction::Payment.new(account: other, destination: 'rDest', amount: '5')
      txs = inner(prepare(batch(payment(outer, 'Fee' => '0', 'SigningPubKey' => ''),
                                { 'RawTransaction' => model })))

      expect(txs.last).to include('TransactionType' => 'Payment', 'Account' => other, 'Sequence' => 500)
    end

    it 'leaves the given Batch untouched' do
      tx = batch(payment(outer), payment(outer))
      before = Marshal.load(Marshal.dump(tx))
      prepare(tx)

      expect(tx).to eq(before)
    end

    describe 'what the ledger would refuse' do
      it 'needs exactly one mode flag' do
        flags = described_class::FLAGS['Batch']
        expect { prepare(batch(payment(outer), payment(outer), flags: 0)) }
          .to raise_error(ArgumentError, /exactly one/)
        expect { prepare(batch(payment(outer), payment(outer), flags: flags['tfOnlyOne'] | flags['tfIndependent'])) }
          .to raise_error(ArgumentError, /exactly one/)
      end

      it 'needs two to eight inner transactions' do
        expect { prepare(batch(payment(outer))) }.to raise_error(ArgumentError, /2 to 8.*has 1/)
        expect { prepare(batch(*Array.new(9) { payment(outer) })) }.to raise_error(ArgumentError, /has 9/)
        expect { prepare(batch.merge('RawTransactions' => nil)) }.to raise_error(ArgumentError, /has 0/)
      end

      it 'refuses an entry that is not a RawTransaction wrapper' do
        bare = payment(outer)['RawTransaction']
        expect { prepare(batch(payment(outer), bare)) }
          .to raise_error(ArgumentError, /RawTransactions\[1\] must be/)
        expect { prepare(batch(payment(outer), { 'Transaction' => bare })) }
          .to raise_error(ArgumentError, /RawTransactions\[1\] must be/)
      end

      it 'refuses a nested Batch' do
        nested = { 'RawTransaction' => { 'TransactionType' => 'Batch', 'Account' => outer } }
        expect { prepare(batch(payment(outer), nested)) }.to raise_error(ArgumentError, /cannot nest/)
      end

      it 'refuses a signed inner transaction' do
        expect { prepare(batch(payment(outer), payment(outer, 'TxnSignature' => 'AB'))) }
          .to raise_error(ArgumentError, /must not be signed/)
        expect { prepare(batch(payment(outer), payment(outer, 'Signers' => []))) }
          .to raise_error(ArgumentError, /must not be signed/)
      end

      it 'refuses an inner fee and an inner key' do
        expect { prepare(batch(payment(outer), payment(outer, 'Fee' => '10'))) }
          .to raise_error(ArgumentError, /Fee "0"/)
        expect { prepare(batch(payment(outer), payment(outer, 'SigningPubKey' => '02AB'))) }
          .to raise_error(ArgumentError, /empty SigningPubKey/)
      end
    end
  end

  describe '.signature_count' do
    it 'counts one per entry, or the nested signers of a signer list' do
      signers = [
        { 'BatchSigner' => { 'Account' => 'rA', 'SigningPubKey' => '02AB', 'TxnSignature' => 'CD' } },
        { 'BatchSigner' => { 'Account' => 'rB', 'Signers' => [{ 'Signer' => {} }, { 'Signer' => {} }] } }
      ]

      expect(described_class.signature_count(signers)).to eq(3)
      expect(described_class.signature_count(nil)).to eq(0)
    end
  end
end
