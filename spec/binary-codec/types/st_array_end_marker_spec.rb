# frozen_string_literal: true

require_relative '../../spec_helper'

# Every element of an STArray is closed by its own ObjectEndMarker (0xE1).
# The codec used to append it only when the element's last byte was not
# already 0xE1, so it went missing whenever an element ended in that byte:
# an AccountID or Memo that happens to end in 0xE1, or a nested object, whose
# own marker is 0xE1 too. The codec fixtures contain no such element, which
# is why they never showed it.
#
# The binaries are ripple-binary-codec's (2.4.1) `encode` of the same JSON.
# rJCxK2hX9tDMzbnn3cg1GU2g19Kfmhzxkp is an AccountID ending in 0xE1.
RSpec.describe 'STArray ObjectEndMarker' do
  ends_in_e1 = 'rJCxK2hX9tDMzbnn3cg1GU2g19Kfmhzxkp'
  other = 'rPMh7Pi9ct699iZUTWaytJUoHcJ7cgyziK'
  inner = lambda do |sequence|
    { 'TransactionType' => 'Payment', 'Flags' => 0x40000000, 'Sequence' => sequence, 'Amount' => '1000',
      'Fee' => '0', 'SigningPubKey' => '', 'Account' => ends_in_e1, 'Destination' => ends_in_e1 }
  end

  {
    'a Memo whose data ends in 0xE1' => [
      { 'Memos' => [{ 'Memo' => { 'MemoData' => 'ABE1' } }, { 'Memo' => { 'MemoData' => 'CD' } }] },
      'F9EA7D02ABE1E1EA7D01CDE1F1'
    ],
    'a Signer whose Account ends in 0xE1' => [
      { 'Signers' => [
        { 'Signer' => { 'SigningPubKey' => '02AB', 'TxnSignature' => 'CD', 'Account' => ends_in_e1 } },
        { 'Signer' => { 'SigningPubKey' => '02AB', 'TxnSignature' => 'CD', 'Account' => other } }
      ] },
      'F3E010730202AB7401CD8114C1D81FB31C42392BA1570431F1CBCBEEBBEF50E1E1' \
      'E010730202AB7401CD8114F51DFC2A09D62CBBA1DFBDD4691DAC96AD98B90FE1F1'
    ],
    'an element that ends in a nested object' => [
      { 'AffectedNodes' => [
        { 'CreatedNode' => { 'LedgerEntryType' => 'AccountRoot',
                             'NewFields' => { 'Balance' => '1000', 'Account' => other } } },
        { 'DeletedNode' => { 'LedgerEntryType' => 'Offer', 'FinalFields' => { 'Flags' => 0 } } }
      ] },
      'F8E3110061E86240000000000003E88114F51DFC2A09D62CBBA1DFBDD4691DAC96AD98B90FE1E1' \
      'E411006FE72200000000E1E1F1'
    ],
    'the inner transactions of a Batch' => [
      { 'RawTransactions' => [{ 'RawTransaction' => inner.call(6) }, { 'RawTransaction' => inner.call(7) }] },
      'F01EE022120000224000000024000000066140000000000003E868400000000000000073008114' \
      'C1D81FB31C42392BA1570431F1CBCBEEBBEF50E18314C1D81FB31C42392BA1570431F1CBCBEEBBEF50E1E1' \
      'E022120000224000000024000000076140000000000003E868400000000000000073008114' \
      'C1D81FB31C42392BA1570431F1CBCBEEBBEF50E18314C1D81FB31C42392BA1570431F1CBCBEEBBEF50E1E1F1'
    ]
  }.each do |name, (json, binary)|
    describe name do
      it 'encodes as ripple-binary-codec does' do
        expect(BinaryCodec.json_to_binary(json)).to eq(binary)
      end

      it 'decodes back to the same JSON' do
        expect(BinaryCodec.binary_to_json(binary)).to eq(json)
      end
    end
  end

  it 'raises on a truncated object rather than returning part of it' do
    truncated = 'F9EA7D02AB'
    expect { BinaryCodec.binary_to_json(truncated) }.to raise_error(StandardError)
  end
end
