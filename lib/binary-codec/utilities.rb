module BinaryCodec

  # Write an 8-bit unsigned integer
  def self.write_uint8(array, value, offset = 0)
    array[offset] = value & 0xFF
  end

  # Read an unsigned 16-bit integer in big-endian format
  def self.read_uint16be(array, offset = 0)
    (array[offset] << 8) + array[offset + 1]
  end

  # Write a 16-bit unsigned integer in big-endian format
  def self.write_uint16be(array, value, offset = 0)
    array[offset] = (value >> 8) & 0xFF
    array[offset + 1] = value & 0xFF
  end

  # Read an unsigned 32-bit integer in big-endian format
  def self.read_uint32be(array, offset = 0)
    (array[offset] << 24) + (array[offset + 1] << 16) +
      (array[offset + 2] << 8) + array[offset + 3]
  end

  # Write an unsigned 32-bit integer to a buffer in big-endian format
  def self.write_uint32be(buffer, value, offset = 0)
    buffer[offset] = (value >> 24) & 0xFF
    buffer[offset + 1] = (value >> 16) & 0xFF
    buffer[offset + 2] = (value >> 8) & 0xFF
    buffer[offset + 3] = value & 0xFF
  end

  # Compare two byte arrays
  def self.equal(array1, array2)
    return false unless array1.length == array2.length
    array1 == array2
  end

  # Compare two arrays of any type
  def self.compare(array1, array2)
    raise 'Cannot compare arrays of different length' if array1.length != array2.length

    array1.each_with_index do |value, i|
      return 1 if value > array2[i]
      return -1 if value < array2[i]
    end

    0
  end

  # Compares two 8-bit aligned arrays
  def self.compare8(array1, array2)
    compare(array1, array2)
  end

  # Compares two 16-bit aligned arrays
  def self.compare16(array1, array2)
    raise 'Array lengths must be even for 16-bit alignment' unless (array1.length % 2).zero? && (array2.length % 2).zero?

    array1.pack('C*').unpack('n*') <=> array2.pack('C*').unpack('n*')
  end

  # Compares two 32-bit aligned arrays
  def self.compare32(array1, array2)
    raise 'Array lengths must be divisible by 4 for 32-bit alignment' unless (array1.length % 4).zero? && (array2.length % 4).zero?

    array1.pack('C*').unpack('N*') <=> array2.pack('C*').unpack('N*')
  end

  # Determine if an array is 16-bit aligned
  def self.aligned16?(array)
    (array.length % 2).zero?
  end

  # Determine if an array is 32-bit aligned
  def self.aligned32?(array)
    (array.length % 4).zero?
  end

end