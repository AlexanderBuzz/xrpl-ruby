# frozen_string_literal: true

require 'json'

# Conformance against the reference fixtures shipped by xrpl.js.
#
# `spec/binary-codec/fixtures/codec-fixtures.json` is the same file
# ripple-binary-codec tests itself with. It had been vendored into this
# repository for a long time without any spec loading it, which is how a set of
# systematic decode defects stayed invisible while the suite reported green.
#
# Every case is checked in both directions, because they fail independently:
# serialising is driven by the field definitions, deserialising additionally
# depends on each type rendering itself the way rippled does. The defects found
# in August 2026 were almost entirely in the second half - `accountState`
# encoded 261/261 while decoding 0/261.
#
# All 287 cases pass in both directions. Should a change break one, fix the
# cause rather than narrowing this spec; if a case has to be parked, mark it
# `pending` with a reason rather than skipping or deleting it, so that RSpec
# fails once it starts passing again.
RSpec.describe 'ripple-binary-codec fixtures' do
  FIXTURES = JSON.parse(
    File.read(File.expand_path('../fixtures/codec-fixtures.json', __dir__))
  ).freeze

  # A short, stable name for a fixture, so a failure points at a case.
  def self.label(entry, index)
    json = entry['json']
    "##{index} #{json['TransactionType'] || json['LedgerEntryType'] || 'unknown'}"
  end

  %w[transactions accountState].each do |group|
    describe group do
      FIXTURES.fetch(group).each_with_index do |entry, index|
        name = label(entry, index)

        it "serialises #{name}" do
          expect(BinaryCodec.json_to_binary(entry['json']).to_s.upcase)
            .to eq(entry['binary'].upcase)
        end

        it "deserialises #{name}" do
          expect(BinaryCodec.binary_to_json(entry['binary'])).to eq(entry['json'])
        end
      end
    end
  end
end
