# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.
#
# Integer 32 methods

class I32

  Digits = "0123456789ABCDEF"

  def self.size; 4; end

  # convert an integer to its string representation in a given base
  def self.itoa(x,base)
    result :String

    raise "itoa base out of range" if base < 2 || base > Digits.length
    if x <= 0
      if x == 0
        return Digits[0]
      else
        return  "-" + self.itoa(0-x, base)
      end
    end

    result = ""
    while x > 0
      remainder = x % base
      x /= base
      result += Digits[remainder]
    end
    result.reverse!
  end

  def to_s
    result :String
    I32.itoa(self, 10)
  end

end
