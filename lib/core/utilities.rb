# frozen_string_literal: true

module Core

  class Utilities

    @address_codec = nil

    def initialize
      @address_codec = AddressCodec.new
    end

    # Returns the singleton instance of the Utilities class.
    # @return [Utilities] The singleton instance.
    def self.instance
      @@instance ||= new
    end

    # Checks if a string is a valid X-address.
    # @param x_address [String] The X-address to check.
    # @return [Boolean] True if the string is a valid X-address, false otherwise.
    def is_x_address?(x_address)
      return false unless x_address.is_a?(String) && x_address.start_with?('X')

      begin
        decoded = @address_codec.decode_x_address(x_address)
        return false if decoded[:account_id].nil? || decoded[:account_id].length != 20

        tag = decoded[:tag]
        return false if tag && (tag < 0 || tag > MAX_32_BIT_UNSIGNED_INT)

        true
      rescue StandardError
        false
      end
    end
  end
end