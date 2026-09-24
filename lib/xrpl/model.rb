# frozen_string_literal: true

module XRPL
  # Common ground for the objects definitions.json describes field by field:
  # transactions (TRANSACTION_FORMATS) and ledger entries (LEDGER_ENTRY_FORMATS).
  #
  # A family - XRPL::Transaction, XRPL::LedgerEntry - is a subclass that names
  # the type field ("TransactionType", "LedgerEntryType") and calls
  # .define_types! with the right tables. That creates one class per entry in
  # the table, with an accessor for every field the type accepts and a
  # constant for every flag it defines. None of them is written by hand, so
  # syncing definitions.json updates them all and they cannot drift.
  #
  # Fields are written in snake_case and stored under the ledger's own
  # PascalCase names, so #to_h hands the binary codec exactly what it expects.
  class Model
    # Raised when required fields are missing or a field is not part of the
    # type.
    class ValidationError < StandardError; end

    # rippled's SOEStyle: what the format says about a field.
    REQUIRED = 0
    OPTIONAL = 1
    DEFAULT = 2

    DEFINITIONS = BinaryCodec::Definitions.instance.raw

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
      # The ledger's name for this type, e.g. "Payment" or "AccountRoot".
      attr_reader :type_name

      # Ledger field name -> optionality, including the common fields.
      attr_reader :format

      # Flag name -> bit, e.g. "tfPartialPayment" => 131072.
      attr_reader :flags

      # The field that names the type: "TransactionType" or "LedgerEntryType".
      # A family defines it.
      def type_field
        raise NotImplementedError, "#{name}.type_field"
      end

      # How the family reads in an error message, e.g. "transaction".
      def label
        raise NotImplementedError, "#{name}.label"
      end

      # Required by the format, but supplied by a later step (autofill,
      # signing) rather than by the caller. Not demanded by #validate!.
      def supplied_later
        []
      end

      # The class for a type name, or nil if the ledger has no such type.
      def for(type)
        const_get(type) if const_defined?(type, false)
      end

      # Build the right subclass from a hash, PascalCase or snake.
      def from(hash)
        type = hash[type_field] || hash[type_field.to_sym] || hash[underscore(type_field).to_sym]
        raise ValidationError, "#{label.capitalize} hash has no #{type_field}" unless type

        klass = self.for(type.to_s)
        raise ValidationError, "Unknown #{label} type #{type}" unless klass

        klass.new(hash)
      end

      # Translates an accessor name to the ledger's field name.
      def resolve(name)
        key = name.to_s
        return key if FIELD_TO_ACCESSOR.key?(key)

        ACCESSOR_TO_FIELD[key] || key
      end

      # Builds one subclass per type in +formats+, with an accessor for every
      # field the type accepts and a constant for every flag it defines.
      #
      # @param formats [Hash] a *_FORMATS table, with its "common" entry
      # @param flags [Hash] the matching *_FLAGS table
      # @param flag_aliases [Hash] type name -> key in +flags+, where they differ
      def define_types!(formats, flags, flag_aliases = {})
        common = formats.fetch('common')

        formats.each do |type, own_format|
          next if type == 'common'

          format = (common + own_format)
                   .to_h { |field| [field['name'], field['optionality']] }
                   .freeze

          klass = Class.new(self)
          klass.instance_variable_set(:@type_name, type)
          klass.instance_variable_set(:@format, format)
          klass.instance_variable_set(:@flags, (flags[flag_aliases.fetch(type, type)] || {}).freeze)

          format.each_key do |field|
            next if field == type_field

            accessor = FIELD_TO_ACCESSOR[field] or next

            klass.define_method(accessor) { self[field] }
            klass.define_method("#{accessor}=") { |value| self[field] = value }
          end

          klass.flags.each do |flag, bit|
            klass.const_set(underscore(flag).upcase, bit)
          end

          const_set(type, klass)
        end
      end
    end

    def initialize(fields = {})
      @fields = {}
      fields.each { |name, value| self[name] = value }
    end

    # Reads a field by accessor name, symbol or ledger name.
    def [](name)
      @fields[self.class.resolve(name)]
    end

    # Writes a field, rejecting anything the type does not define. The type
    # field itself is accepted, and checked, so a hash read off the ledger can
    # be passed in whole.
    def []=(name, value)
      field = self.class.resolve(name)

      if field == self.class.type_field
        return if value.to_s == self.class.type_name

        raise ValidationError, "#{self.class.type_name} cannot carry #{field} #{value}"
      end

      unless self.class.format.key?(field)
        raise ValidationError, "#{self.class.type_name} has no field #{field}"
      end

      value.nil? ? @fields.delete(field) : @fields[field] = value
    end

    # The object as the binary codec wants it: ledger field names, with the
    # type field filled in.
    def to_h
      { self.class.type_field => self.class.type_name }.merge(@fields)
    end
    alias to_hash to_h

    # Fields the format requires that have not been set, ignoring the ones a
    # later step provides.
    def missing_fields
      self.class.format
          .select { |_, optionality| optionality == REQUIRED }
          .keys
          .reject { |field| field == self.class.type_field }
          .reject { |field| self.class.supplied_later.include?(field) || @fields.key?(field) }
    end

    def valid?
      missing_fields.empty?
    end

    # Raises unless every required field is present.
    def validate!
      missing = missing_fields
      return self if missing.empty?

      raise ValidationError,
            "#{self.class.type_name} is missing #{missing.join(', ')}"
    end

    # Whether a flag is set in Flags. Takes the ledger's name
    # ("lsfDefaultRipple"), the constant's name (:lsf_default_ripple) or the
    # bit itself.
    def flag?(flag)
      (self['Flags'].to_i & self.class.flag_bit(flag)) != 0
    end

    # The names of the flags set in Flags, in the ledger's spelling.
    def flag_names
      value = self['Flags'].to_i
      self.class.flags.select { |_, bit| (value & bit) != 0 }.keys
    end

    # The bit for a flag given by ledger name, constant name or bit.
    def self.flag_bit(flag)
      return flag if flag.is_a?(Integer)

      key = flag.to_s
      _, bit = flags.find { |name, _| name == key || underscore(name) == key.downcase }
      bit or raise ArgumentError, "#{type_name} has no flag #{flag}"
    end

    # The serialised object, as hex.
    def to_blob
      BinaryCodec.json_to_binary(to_h)
    end

    def ==(other)
      other.is_a?(Model) && other.to_h == to_h
    end
    alias eql? ==

    def hash
      to_h.hash
    end

    def inspect
      "#<#{self.class.name} #{to_h.inspect}>"
    end
  end
end
