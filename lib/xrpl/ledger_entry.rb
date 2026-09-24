# frozen_string_literal: true

module XRPL
  # A ledger entry - AccountRoot, RippleState, Offer, Escrow and the other
  # objects that make up the ledger's state - built from LEDGER_ENTRY_FORMATS
  # in definitions.json, the same way XRPL::Transaction is built from
  # TRANSACTION_FORMATS.
  #
  #     entry = XRPL::LedgerEntry.from(response.dig('result', 'node'))
  #     entry.class          # => XRPL::LedgerEntry::AccountRoot
  #     entry.balance        # => "370000000"
  #     entry.flag?(:lsf_default_ripple)
  #     entry.flag_names     # => ["lsfDefaultRipple"]
  #
  # Where rippled hands out the entry's own hash under "index" (ledger_entry,
  # account_objects, ledger_data), that value is kept as #index; it is not a
  # field of the object and is left out of #to_h.
  class LedgerEntry < Model
    # Fields every ledger entry carries, regardless of type.
    COMMON_FORMAT = DEFINITIONS['LEDGER_ENTRY_FORMATS'].fetch('common').freeze

    # LEDGER_ENTRY_FLAGS keys DirectoryNode's flags under rippled's short
    # name for the type.
    FLAG_ALIASES = { 'DirectoryNode' => 'DirNode' }.freeze

    # The entry's hash, as rippled reports it under "index".
    attr_accessor :index

    class << self
      # The ledger's name for this entry type, e.g. "AccountRoot".
      alias ledger_entry_type type_name

      def type_field
        'LedgerEntryType'
      end

      def label
        'ledger entry'
      end
    end

    def []=(name, value)
      if name.to_s == 'index'
        @index = value
        return
      end

      super
    end

    define_types!(DEFINITIONS['LEDGER_ENTRY_FORMATS'], DEFINITIONS['LEDGER_ENTRY_FLAGS'], FLAG_ALIASES)
  end
end
