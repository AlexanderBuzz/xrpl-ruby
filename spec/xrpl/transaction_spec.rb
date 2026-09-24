# frozen_string_literal: true

require 'json'

# The transaction models are generated from TRANSACTION_FORMATS, so most of
# what is worth testing is that the generation covers the definitions and that
# the translation between snake_case accessors and the ledger's own field names
# is exact in both directions.
RSpec.describe XRPL::Transaction do
  FORMATS = BinaryCodec::Definitions.instance.raw['TRANSACTION_FORMATS'].freeze
  TX_TYPES = (FORMATS.keys - ['common']).freeze

  describe 'generation' do
    it 'defines a class for every transaction type in the definitions' do
      missing = TX_TYPES.reject { |type| described_class.for(type) }

      expect(missing).to be_empty
    end

    it 'defines no class the definitions do not name' do
      generated = described_class.constants
                                 .map { |c| described_class.const_get(c) }
                                 .select { |c| c.is_a?(Class) && c < described_class }
                                 .map(&:transaction_type)

      expect(generated).to match_array(TX_TYPES)
    end

    it 'gives each type the common fields as well as its own' do
      expect(XRPL::Transaction::Payment.format).to include(
        'Account' => described_class::REQUIRED,      # common
        'Destination' => described_class::REQUIRED,  # own
        'SendMax' => described_class::OPTIONAL,
        'Paths' => described_class::DEFAULT
      )
    end
  end

  describe 'accessor names' do
    it 'maps every field to a distinct accessor' do
      expect(described_class::ACCESSOR_TO_FIELD.size)
        .to eq(described_class::FIELD_TO_ACCESSOR.size)
    end

    # The cases that a naive underscore conversion gets wrong.
    {
      'Destination' => 'destination',
      'SendMax' => 'send_max',
      'InvoiceID' => 'invoice_id',
      'CredentialIDs' => 'credential_ids',
      'DomainID' => 'domain_id',
      'XChainClaimID' => 'xchain_claim_id',
      'NFTokenID' => 'nftoken_id',
      'MPTokenIssuanceID' => 'mptoken_issuance_id',
      'URI' => 'uri'
    }.each do |field, accessor|
      it "maps #{field} to #{accessor}" do
        expect(described_class::FIELD_TO_ACCESSOR[field]).to eq(accessor)
      end
    end
  end

  describe 'building' do
    subject(:payment) do
      XRPL::Transaction::Payment.new(
        account: 'rBKPS4oLSaV2KVVuHH8EpQqMGgGefGFQs7',
        destination: 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
        amount: '1000000'
      )
    end

    it 'stores fields under the ledger names and sets the type' do
      expect(payment.to_h).to eq(
        'TransactionType' => 'Payment',
        'Account' => 'rBKPS4oLSaV2KVVuHH8EpQqMGgGefGFQs7',
        'Destination' => 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
        'Amount' => '1000000'
      )
    end

    it 'reads and writes through accessors' do
      payment.destination_tag = 42

      expect(payment.destination_tag).to eq(42)
      expect(payment.to_h['DestinationTag']).to eq(42)
    end

    it 'accepts ledger field names too' do
      built = XRPL::Transaction::Payment.new(
        'Account' => 'rBKPS4oLSaV2KVVuHH8EpQqMGgGefGFQs7',
        'Destination' => 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
        'Amount' => '1000000'
      )

      expect(built).to eq(payment)
    end

    it 'refuses a field the type does not define' do
      expect { payment.send(:[]=, 'LimitAmount', {}) }
        .to raise_error(described_class::ValidationError, /Payment has no field LimitAmount/)
    end

    it 'removes a field set to nil' do
      payment.destination_tag = 42
      payment.destination_tag = nil

      expect(payment.to_h).not_to have_key('DestinationTag')
    end
  end

  describe 'validation' do
    it 'passes when the required fields are set' do
      tx = XRPL::Transaction::CheckCreate.new(
        account: 'rBKPS4oLSaV2KVVuHH8EpQqMGgGefGFQs7',
        destination: 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
        send_max: '1000'
      )

      expect(tx).to be_valid
      expect(tx.validate!).to be(tx)
    end

    it 'names what is missing' do
      tx = XRPL::Transaction::CheckCreate.new(account: 'rBKPS4oLSaV2KVVuHH8EpQqMGgGefGFQs7')

      expect(tx.missing_fields).to contain_exactly('Destination', 'SendMax')
      expect { tx.validate! }
        .to raise_error(described_class::ValidationError, /CheckCreate is missing/)
    end

    # "Required" here is rippled's serialisation requirement, not a statement
    # about what a transaction needs to make sense: TrustSet.LimitAmount is
    # optional in the format although no useful TrustSet omits it.
    it 'follows the format rather than intuition' do
      tx = XRPL::Transaction::TrustSet.new(account: 'rBKPS4oLSaV2KVVuHH8EpQqMGgGefGFQs7')

      expect(XRPL::Transaction::TrustSet.format['LimitAmount'])
        .to eq(described_class::OPTIONAL)
      expect(tx).to be_valid
    end

    # Sequence, Fee and SigningPubKey are required by the format but come from
    # autofill and signing, so demanding them here would make validate! useless
    # at the point where it is worth running.
    it 'does not demand the fields autofill supplies' do
      tx = XRPL::Transaction::Payment.new(
        account: 'rBKPS4oLSaV2KVVuHH8EpQqMGgGefGFQs7',
        destination: 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
        amount: '1000000'
      )

      expect(tx.missing_fields).to be_empty
    end
  end

  describe 'flags' do
    it 'exposes the flags of the type as constants' do
      expect(XRPL::Transaction::Payment::TF_PARTIAL_PAYMENT).to eq(131_072)
      expect(XRPL::Transaction::Payment::TF_NO_RIPPLE_DIRECT).to eq(65_536)
    end

    it 'does not put another type\'s flags on a type' do
      expect(XRPL::Transaction::TrustSet.const_defined?(:TF_PARTIAL_PAYMENT, false))
        .to be(false)
    end
  end

  describe 'serialisation' do
    it 'round-trips through the binary codec' do
      tx = XRPL::Transaction::Payment.new(
        account: 'rBKPS4oLSaV2KVVuHH8EpQqMGgGefGFQs7',
        destination: 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
        amount: '1000000',
        fee: '10',
        sequence: 1,
        flags: XRPL::Transaction::Payment::TF_PARTIAL_PAYMENT
      )

      expect(BinaryCodec.binary_to_json(tx.to_blob)).to eq(tx.to_h)
    end
  end

  describe '.from' do
    it 'builds the right subclass from a transaction hash' do
      tx = described_class.from(
        'TransactionType' => 'OfferCreate',
        'Account' => 'rBKPS4oLSaV2KVVuHH8EpQqMGgGefGFQs7',
        'TakerGets' => '1000',
        'TakerPays' => { 'currency' => 'USD', 'issuer' => 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh', 'value' => '1' }
      )

      expect(tx).to be_a(XRPL::Transaction::OfferCreate)
      expect(tx.taker_gets).to eq('1000')
    end

    it 'rejects an unknown type' do
      expect { described_class.from('TransactionType' => 'Nonsense') }
        .to raise_error(described_class::ValidationError, /Unknown transaction type/)
    end

    it 'rejects a hash with no type' do
      expect { described_class.from('Account' => 'r...') }
        .to raise_error(described_class::ValidationError, /no TransactionType/)
    end
  end

  # Every reference fixture is a real transaction; each must survive a trip
  # through its model unchanged.
  describe 'round trip through the reference fixtures' do
    fixtures = JSON.parse(
      File.read(File.expand_path('../binary-codec/fixtures/codec-fixtures.json', __dir__))
    ).fetch('transactions')

    fixtures.each_with_index do |entry, index|
      json = entry['json']

      it "reproduces ##{index} #{json['TransactionType']}" do
        model = described_class.from(json)

        expect(model).to be_a(described_class.for(json['TransactionType']))
        expect(model.to_h).to eq(json)
      end
    end
  end

  describe 'flags' do
    let(:tx) do
      XRPL::Transaction::Payment.new(
        account: 'rBKPS4oLSaV2KVVuHH8EpQqMGgGefGFQs7',
        flags: XRPL::Transaction::Payment::TF_PARTIAL_PAYMENT
      )
    end

    it 'answers which flags are set, by any of their names' do
      expect(tx.flag?('tfPartialPayment')).to be true
      expect(tx.flag?(:tf_partial_payment)).to be true
      expect(tx.flag?(:tf_no_ripple_direct)).to be false
      expect(tx.flag_names).to eq(['tfPartialPayment'])
    end

    it 'treats a transaction without Flags as having none set' do
      expect(XRPL::Transaction::Payment.new.flag?(:tf_partial_payment)).to be false
    end
  end

  it 'rejects a hash whose type contradicts the class' do
    expect { XRPL::Transaction::Payment.new('TransactionType' => 'TrustSet') }
      .to raise_error(described_class::ValidationError, /Payment cannot carry TransactionType TrustSet/)
  end

  # The models follow definitions.json, so a sync reaches them without any
  # code change. rippled 3.4.0 (LendingProtocolV1_1) is the first such sync.
  describe 'rippled 3.4.0 formats' do
    it 'gives VaultCreate the closed-ended vault fields' do
      tx = XRPL::Transaction::VaultCreate.new(
        account: 'rBKPS4oLSaV2KVVuHH8EpQqMGgGefGFQs7',
        vault_kind: 1,
        subscription_date: 800_000_000,
        redemption_date: 810_000_000
      )

      expect(tx.to_h).to include('VaultKind' => 1, 'SubscriptionDate' => 800_000_000,
                                 'RedemptionDate' => 810_000_000)
    end
  end
end
