# Rubinius WebAssembly VM
# Copyright (c) 2019, Laurent Julliard and contributors
# All rights reserved.
#
# Integer 32 methods

class String; end

class I32
  ConvertString = "0123456789ABCDEF"

  def self.size; 4; end

  def to_str(base)
    result :String
    "0"
=begin
    # TODO
    if n < base
      return convertString[n]
    else
      return toStr(n//base,base) + convertString[n%base]
    end
=end
  end

  def to_s
    result :String
    self.to_str(10)
  end

end
