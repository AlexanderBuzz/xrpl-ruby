# frozen_string_literal: true

module XRPL
  # A transaction, built from the field formats in definitions.json.
  #
  # The subclasses below are not written by hand: one is created for each entry
  # in TRANSACTION_FORMATS when this file loads, so syncing definitions.json
  # updates the models with it and they cannot drift from the ledger.
  #
  #     tx = XRPL::Transaction::Payment.new(
  #       account: wallet.classic_address,
  #       destination: receiver.classic_address,
  #       amount: '1000000'
  #     )
  #     tx.validate!
  #     client.submit_and_wait(tx, wallet: wallet)
  #
  # Fields are given in snake_case and stored under the ledger's own PascalCase
  # names, so #to_h hands the binary codec exactly what it expects. A plain
  # Hash still works everywhere a transaction is accepted; these classes are an
  # addition, not a replacement.
  class Transaction
    # Raised when required fields are missing or a field is not part of the
    # transaction type.
    class ValidationError < StandardError; end

    # rippled's SOEStyle: what the format says about a field.
    REQUIRED = 0
    OPTIONAL = 1
    DEFAULT = 2

    DEFINITIONS = BinaryCodec::Definitions.instance.raw

    # Fields every transaction carries, regardless of type.
    COMMON_FORMAT = DEFINITIONS['TRANSACTION_FORMATS'].fetch('common').freeze

    # Required by the format, but supplied by autofill and signing rather than
    # by the caller. Demanding them up front would make #validate! useless at
    # the point where it is actually worth running.
    SUPPLIED_LATER = %w[
      TransactionType Sequence Fee SigningPubKey TxnSignature LastLedgerSequence
    ].freeze

    # Ledger field name -> snake_case accessor, and back.
    #
    # XChain, NFToken and MPToken are brand names rather than acronyms, so they
    # are folded to a single word the way the reference SDKs write them.
    def self.underscore(name)
      name
        .sub(/\AXChain/, 'Xchain')
        .sub(/\ANFToken/, 'Nftoken')
        .sub(/\AMPToken/, 'Mptoken')
        .gsub(/([A-Z]{2,})s(?=[A-Z]|\z)/) { "#{Regexp.last_match(1).capitalize}s" }
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .downcase
    end

    FIELD_TO_ACCESSOR = DEFINITIONS['FIELDS'].to_h { |name, _| [name, underscore(name)] }.freeze
    ACCESSOR_TO_FIELD = FIELD_TO_ACCESSOR.invert.freeze

    if ACCESSOR_TO_FIELD.size != FIELD_TO_ACCESSOR.size
      raise "Ambiguous accessor names in definitions.json"
    end

    class << self
      # The ledger's name for this transaction type, e.g. "Payment".
      attr_reader :transaction_type

      # Ledger field name -> optionality, including the common fields.
      attr_reader :format

      # Flag name -> bit, e.g. "tfPartialPayment" => 131072.
      attr_reader :flags
    end

    # The class for a transaction type name, or nil if the ledger has no such
    # type.
    def self.for(type)
      const_get(type) if const_defined?(type, false)
    end

    # Build the right subclass from a transaction hash, PascalCase or snake.
    def self.from(hash)
      type = hash['TransactionType'] || hash[:TransactionType] || hash[:transaction_type]
      raise ValidationError, 'Transaction hash has no TransactionType' unless type

      klass = self.for(type.to_s)
      raise ValidationError, "Unknown transaction type #{type}" unless klass

      klass.new(hash)
    end

    def initialize(fields = {})
      @fields = {}
      fields.each { |name, value| self[name] = value }
    end

    # Reads a field by accessor name, symbol or ledger name.
    def [](name)
      @fields[self.class.resolve(name)]
    end

    # Writes a field, rejecting anything the type does not define.
    def []=(name, value)
      field = self.class.resolve(name)

      unless self.class.format.key?(field)
        raise ValidationError, "#{self.class.transaction_type} has no field #{field}"
      end

      value.nil? ? @fields.delete(field) : @fields[field] = value
    end

    # Translates an accessor name to the ledger's field name.
    def self.resolve(name)
      key = name.to_s
      return key if FIELD_TO_ACCESSOR.key?(key)

      ACCESSOR_TO_FIELD[key] || key
    end

    # The transaction as the binary codec wants it: ledger field names, with
    # TransactionType filled in.
    def to_h
      { 'TransactionType' => self.class.transaction_type }.merge(@fields)
    end
    alias to_hash to_h

    # Fields the format requires that have not been set, ignoring the ones
    # autofill and signing provide.
    def missing_fields
      self.class.format
          .select { |field, optionality| optionality == REQUIRED }
          .keys
          .reject { |field| SUPPLIED_LATER.include?(field) || @fields.key?(field) }
    end

    def valid?
      missing_fields.empty?
    end

    # Raises unless every required field is present.
    def validate!
      missing = missing_fields
      return self if missing.empty?

      raise ValidationError,
            "#{self.class.transaction_type} is missing #{missing.join(', ')}"
    end

    # The serialised transaction, as hex.
    def to_blob
      BinaryCodec.json_to_binary(to_h)
    end

    def ==(other)
      other.is_a?(Transaction) && other.to_h == to_h
    end
    alias eql? ==

    def hash
      to_h.hash
    end

    def inspect
      "#<#{self.class.name} #{to_h.inspect}>"
    end

    # Builds one subclass per transaction type, with an accessor for every
    # field the type accepts and a constant for every flag it defines.
    def self.define_types!
      DEFINITIONS['TRANSACTION_FORMATS'].each do |type, own_format|
        next if type == 'common'

        format = (COMMON_FORMAT + own_format)
                 .to_h { |field| [field['name'], field['optionality']] }
                 .freeze

        klass = Class.new(self)
        klass.instance_variable_set(:@transaction_type, type)
        klass.instance_variable_set(:@format, format)
        klass.instance_variable_set(:@flags, (DEFINITIONS['TRANSACTION_FLAGS'][type] || {}).freeze)

        format.each_key do |field|
          accessor = FIELD_TO_ACCESSOR[field] or next

          klass.define_method(accessor) { self[field] }
          klass.define_method("#{accessor}=") { |value| self[field] = value }
        end

        klass.flags.each do |name, bit|
          klass.const_set(underscore(name).upcase, bit)
        end

        const_set(type, klass)
      end
    end

    define_types!
  end
end
