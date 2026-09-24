# frozen_string_literal: true

require 'json'

# The ledger entry models are generated from LEDGER_ENTRY_FORMATS the way the
# transaction models are generated from TRANSACTION_FORMATS. The reference
# fixtures hold 263 real ledger entries across every type, so the strongest
# check is that each of them survives a trip through its model unchanged.
RSpec.describe XRPL::LedgerEntry do
  FIXTURE_ENTRIES = JSON.parse(
    File.read(File.expand_path('../binary-codec/fixtures/codec-fixtures.json', __dir__))
  ).fetch('accountState').freeze

  LE_FORMATS = BinaryCodec::Definitions.instance.raw['LEDGER_ENTRY_FORMATS'].freeze
  LE_TYPES = (LE_FORMATS.keys - ['common']).freeze

  describe 'generation' do
    it 'defines a class for every ledger entry type in the definitions' do
      missing = LE_TYPES.reject { |type| described_class.for(type) }

      expect(missing).to be_empty
    end

    it 'defines no class the definitions do not name' do
      generated = described_class.constants
                                 .map { |c| described_class.const_get(c) }
                                 .select { |c| c.is_a?(Class) && c < described_class }
                                 .map(&:ledger_entry_type)

      expect(generated).to match_array(LE_TYPES)
    end

    it 'gives each type the common fields as well as its own' do
      expect(XRPL::LedgerEntry::AccountRoot.format).to include(
        'Flags' => described_class::REQUIRED,        # common
        'LedgerIndex' => described_class::OPTIONAL,  # common
        'Balance' => described_class::REQUIRED,
        'RegularKey' => described_class::OPTIONAL
      )
    end

    it 'exposes the flags of a type as constants' do
      expect(XRPL::LedgerEntry::AccountRoot::LSF_DEFAULT_RIPPLE).to eq(8_388_608)
      expect(XRPL::LedgerEntry::RippleState::LSF_LOW_RESERVE).to eq(65_536)
    end

    # LEDGER_ENTRY_FLAGS keys these under rippled's short name, "DirNode".
    it 'finds the DirectoryNode flags under their alias' do
      expect(XRPL::LedgerEntry::DirectoryNode.flags.keys)
        .to include('lsfNFTokenBuyOffers', 'lsfNFTokenSellOffers')
    end
  end

  describe 'round trip through the reference fixtures' do
    FIXTURE_ENTRIES.each_with_index do |entry, index|
      json = entry['json']

      it "reproduces ##{index} #{json['LedgerEntryType']}" do
        model = described_class.from(json)

        expect(model).to be_a(described_class.for(json['LedgerEntryType']))
        expect(model.to_h).to eq(json)
      end
    end
  end

  describe 'accessors' do
    let(:entry) do
      XRPL::LedgerEntry::AccountRoot.new(
        account: 'rBKPS4oLSaV2KVVuHH8EpQqMGgGefGFQs7',
        balance: '370000000',
        flags: XRPL::LedgerEntry::AccountRoot::LSF_DEFAULT_RIPPLE | XRPL::LedgerEntry::AccountRoot::LSF_DISABLE_MASTER
      )
    end

    it 'reads and writes in snake_case, stores under the ledger name' do
      entry.owner_count = 3

      expect(entry.balance).to eq('370000000')
      expect(entry['OwnerCount']).to eq(3)
      expect(entry.to_h).to include('Balance' => '370000000', 'OwnerCount' => 3)
    end

    it 'rejects a field the type does not define' do
      expect { XRPL::LedgerEntry::Offer.new(balance: '1') }
        .to raise_error(described_class::ValidationError, /Offer has no field Balance/)
    end

    it 'answers which flags are set, by any of their names' do
      expect(entry.flag?('lsfDefaultRipple')).to be true
      expect(entry.flag?(:lsf_default_ripple)).to be true
      expect(entry.flag?(XRPL::LedgerEntry::AccountRoot::LSF_DISABLE_MASTER)).to be true
      expect(entry.flag?(:lsf_deposit_auth)).to be false
      expect(entry.flag_names).to contain_exactly('lsfDefaultRipple', 'lsfDisableMaster')
    end

    it 'rejects a flag the type does not define' do
      expect { entry.flag?(:lsf_sell) }.to raise_error(ArgumentError, /AccountRoot has no flag/)
    end
  end

  describe '.from' do
    it 'keeps the index rippled reports, outside the fields' do
      entry = described_class.from(
        'LedgerEntryType' => 'Ticket',
        'Account' => 'rBKPS4oLSaV2KVVuHH8EpQqMGgGefGFQs7',
        'TicketSequence' => 5,
        'index' => 'AB' * 32
      )

      expect(entry).to be_a(XRPL::LedgerEntry::Ticket)
      expect(entry.index).to eq('AB' * 32)
      expect(entry.to_h).not_to have_key('index')
    end

    it 'rejects an unknown type' do
      expect { described_class.from('LedgerEntryType' => 'Nonsense') }
        .to raise_error(described_class::ValidationError, /Unknown ledger entry type/)
    end

    it 'rejects a hash with no type' do
      expect { described_class.from('Account' => 'r...') }
        .to raise_error(described_class::ValidationError, /no LedgerEntryType/)
    end

    it 'rejects a hash whose type contradicts the class' do
      expect { XRPL::LedgerEntry::Offer.new('LedgerEntryType' => 'Ticket') }
        .to raise_error(described_class::ValidationError, /Offer cannot carry LedgerEntryType Ticket/)
    end
  end

  it 'serialises like the hash it stands for' do
    json = FIXTURE_ENTRIES.first['json']

    expect(described_class.from(json).to_blob).to eq(BinaryCodec.json_to_binary(json))
  end
end
