# frozen_string_literal: true

require 'json'

# Structural checks on definitions.json.
#
# The file is a generated artifact, taken verbatim from XRPLF. Syncing it can
# introduce a type or a field the codec has no implementation for, and nothing
# else in the suite would notice until someone tried to serialise the field:
# the August 2026 sync surfaced `Number`, which 17 serialised fields had been
# referencing without a class existing for it.
#
# These specs fail on that class of drift rather than on any particular
# revision of the file, so a future sync does not need them rewritten.
RSpec.describe 'definitions.json' do
  DEFINITIONS = JSON.parse(
    File.read(File.expand_path('../../lib/binary-codec/enums/definitions.json', __dir__))
  ).freeze

  # `Unknown` is the sentinel type of the Invalid and Generic pseudo-fields.
  # It has no wire representation and needs no class.
  UNIMPLEMENTABLE_TYPES = %w[Unknown Done NotPresent].freeze

  def self.serialised_field_types
    DEFINITIONS['FIELDS']
      .select { |(_, info)| info['isSerialized'] }
      .map { |(_, info)| info['type'] }
      .uniq - UNIMPLEMENTABLE_TYPES
  end

  describe 'type coverage' do
    serialised_field_types.sort.each do |type|
      it "resolves #{type} to a class" do
        expect(BinaryCodec::SerializedType.get_type_by_name(type))
          .to be < BinaryCodec::SerializedType
      end
    end
  end

  describe 'field integrity' do
    it 'gives every field a type that appears in TYPES' do
      unknown = DEFINITIONS['FIELDS'].reject do |(_, info)|
        DEFINITIONS['TYPES'].key?(info['type'])
      end

      expect(unknown.map(&:first)).to be_empty
    end

    it 'resolves every serialised field through Definitions' do
      definitions = BinaryCodec::Definitions.instance

      missing = DEFINITIONS['FIELDS']
                .select { |(_, info)| info['isSerialized'] }
                .reject { |(_, info)| UNIMPLEMENTABLE_TYPES.include?(info['type']) }
                .map(&:first)
                .reject { |name| definitions.get_field_instance(name) }

      expect(missing).to be_empty
    end
  end

  # The file is taken verbatim from XRPLF (xrpl.js and xrpl-py ship byte
  # identical copies). Nothing in the codec behaves differently because of the
  # entries below - no fixture exercises them yet - so without these checks a
  # revert to an older definitions.json would go unnoticed.
  describe 'sync with the reference definitions' do
    it 'uses the reference names for the wide hash types' do
      expect(DEFINITIONS['TYPES']).to include('Hash384' => 22, 'Hash512' => 23)
      expect(DEFINITIONS['TYPES'].keys).not_to include('UInt384', 'UInt512')
    end

    it 'knows the Sponsorship ledger entry and transactions' do
      expect(DEFINITIONS['LEDGER_ENTRY_TYPES']).to have_key('Sponsorship')
      expect(DEFINITIONS['TRANSACTION_TYPES'])
        .to include('SponsorshipSet', 'SponsorshipTransfer')
    end

    it 'knows the confidential MPT transactions' do
      expect(DEFINITIONS['TRANSACTION_TYPES']).to include(
        'ConfidentialMPTSend', 'ConfidentialMPTClawback', 'ConfidentialMPTConvert',
        'ConfidentialMPTConvertBack', 'ConfidentialMPTMergeInbox'
      )
    end

    it 'carries the MPT and sponsorship fields' do
      names = DEFINITIONS['FIELDS'].map(&:first)

      expect(names).to include('TakerGetsMPT', 'TakerPaysMPT', 'ReferenceHolding')
      expect(names).to include('Sponsor', 'Sponsee', 'SponsorSignature')
      expect(names).to include('ImmutableFlags')
      expect(names).not_to include('MutableFlags') # renamed upstream
    end

    # tecHOOK_REJECTED is a Xahau result code and has no place in the XRP
    # Ledger definitions. It was present before the August 2026 sync.
    it 'carries no Xahau result codes' do
      expect(DEFINITIONS['TRANSACTION_RESULTS']).not_to have_key('tecHOOK_REJECTED')
    end
  end

  # Every type is called as to_json(definitions, field_name) from STObject. A
  # zero-arity to_json raises ArgumentError for every nested occurrence of that
  # type - which is how Currency silently dropped BaseAsset and QuoteAsset from
  # PriceDataSeries until August 2026.
  describe 'the to_json contract' do
    it 'is honoured by every serialized type' do
      offenders = ObjectSpace.each_object(Class)
                             .select { |k| k <= BinaryCodec::SerializedType }
                             .select do |k|
        method = k.instance_method(:to_json)
        method.owner.to_s.start_with?('BinaryCodec') && method.arity.zero?
      end

      expect(offenders.map(&:name)).to be_empty
    end
  end
end
