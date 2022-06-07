# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.
#
# Integer 32 methods

require_relative '../string'

class I32

  DIGITS = "0123456789ABCDEF"

  def self.size; 4; end

  # convert an integer to its string representation in a given base
  def self.itoa(x,base)
    result :String

    raise "itoa base out of range" if base < 2 || base > DIGITS.length
    if x <= 0
      if x == 0
        return DIGITS[0]
      else
        return  "-" + self.itoa(0-x, base)
      end
    end

    result = ""
    while x > 0
      remainder = x % base
      x /= base
      result += DIGITS[remainder]
    end
    result.reverse!
  end

  def to_s
    result :String
    I32.itoa(self, 10)
  end

  def chr
    result :String
    raise "out of char range" if self > 255 || self < 0
    stg = String.new(0,1)
    Memory.store32_8(stg.ptr, self)
    stg
  end

end
