module Core

  class Base58XRP < BaseX

    XRP_ALPHABET = "rpshnaf39wBUDNEGHJKLM4PQRST7VWXYZ2bcdeCg65jkm8oFqi1tuvAxyz"

    def initialize
      super(XRP_ALPHABET)
    end
  end

end