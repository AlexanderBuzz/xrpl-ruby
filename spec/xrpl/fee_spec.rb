# frozen_string_literal: true

# The rules are the ones xrpl.js applies in calculateFeePerTransactionType;
# the numbers below are worked from them with a base fee of 10 drops.
RSpec.describe XRPL::Fee do
  # A positional options hash, so that a braces-less string-keyed hash is the
  # transaction and not swallowed as keywords.
  def fee(tx, opts = {})
    described_class.calculate(tx, base_fee: 10, **opts)
  end

  it 'charges an ordinary transaction the base fee' do
    expect(fee('TransactionType' => 'Payment')).to eq(10)
  end

  it 'accepts a transaction model' do
    expect(fee(XRPL::Transaction::Payment.new)).to eq(10)
  end

  it 'adds one base fee per signature for a multisigned transaction' do
    expect(fee({ 'TransactionType' => 'Payment' }, signers_count: 2)).to eq(30)
  end

  describe 'EscrowFinish' do
    it 'pays for the size of its Fulfillment: base × (33 + bytes / 16)' do
      # 32 bytes: 10 × (33 + 2) = 350
      expect(fee('TransactionType' => 'EscrowFinish', 'Fulfillment' => 'A0' * 32)).to eq(350)
    end

    it 'rounds the fraction of a 16 byte block up' do
      # 39 bytes: 10 × (33 + 39/16) = 354.375 -> 355
      expect(fee('TransactionType' => 'EscrowFinish', 'Fulfillment' => 'A0' * 39)).to eq(355)
    end

    it 'costs the base fee without a Fulfillment' do
      expect(fee('TransactionType' => 'EscrowFinish')).to eq(10)
    end
  end

  describe 'the reserve-priced types' do
    %w[AccountDelete AMMCreate VaultCreate].each do |type|
      it "charges #{type} the owner reserve instead of a fee" do
        expect(fee({ 'TransactionType' => type }, owner_reserve: 200_000)).to eq(200_000)
      end
    end

    it 'fetches the reserve lazily' do
      fetched = false
      fee({ 'TransactionType' => 'Payment' }, owner_reserve: -> { fetched = true })
      expect(fetched).to be false

      expect(fee({ 'TransactionType' => 'AccountDelete' }, owner_reserve: -> { fetched = true; 200_000 }))
        .to eq(200_000)
      expect(fetched).to be true
    end

    it 'is not capped' do
      expect(fee({ 'TransactionType' => 'AMMCreate' }, owner_reserve: 5_000_000, max_fee: 100))
        .to eq(5_000_000)
    end

    it 'refuses to guess the reserve' do
      expect { fee('TransactionType' => 'AccountDelete') }
        .to raise_error(ArgumentError, /owner reserve/)
    end
  end

  it 'charges a Batch two base fees plus those of its inner transactions' do
    batch = {
      'TransactionType' => 'Batch',
      'RawTransactions' => [
        { 'RawTransaction' => { 'TransactionType' => 'Payment' } },
        { 'RawTransaction' => { 'TransactionType' => 'EscrowFinish', 'Fulfillment' => 'A0' * 32 } }
      ]
    }

    expect(fee(batch)).to eq(20 + 10 + 350)
  end

  it 'charges a confidential MPT transaction ten base fees' do
    expect(fee('TransactionType' => 'ConfidentialMPTSend')).to eq(100)
  end

  it 'caps an ordinary fee at max_fee' do
    expect(described_class.calculate({ 'TransactionType' => 'Payment' }, base_fee: 5_000_000))
      .to eq(described_class::MAX_FEE_DROPS)
    expect(described_class.calculate({ 'TransactionType' => 'Payment' }, base_fee: 500, max_fee: 100))
      .to eq(100)
  end
end
