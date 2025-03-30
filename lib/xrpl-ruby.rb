# frozen_string_literal: true

require_relative 'core/core'

require_relative 'address-codec/codec'
require_relative 'address-codec/xrp_codec'
require_relative 'address-codec/address_codec'

require_relative 'binary-codec/enums/fields'
require_relative 'binary-codec/enums/definitions'
require_relative 'binary-codec/serdes/binary_parser'
require_relative 'binary-codec/serdes/bytes_list'
require_relative 'binary-codec/types/serialized_type'
require_relative 'binary-codec/types/hash'