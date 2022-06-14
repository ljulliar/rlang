# Rlang WebAssembly compiler
# Copyright (c) 2019-2022, Laurent Julliard and contributors
# All rights reserved.

require 'kernel'
require 'string'
require 'array'

module Base64

  include Kernel

  BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  BASE64_CHARS_URLSAFE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  PAD = "="
  LINE_SEP = "\n" # Would be "\r\n" on Windows

  # Tables of valid ASCII char maps for Base64 decoding.
  # -1    : the char is invalid
  #  >= 0 : the binary value to use for decoding (note: the '=' sign is also 0)
  # 
  BASE64_CHAR_MAP = 
    [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
     -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, -1, -1, 63, 
     52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1, 0, -1, -1, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 
     9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1, -1, -1, -1, -1, -1, 26, 
     27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 
     51, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
     -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
     -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
     -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
     -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
     -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1] 

  BASE64_CHAR_MAP_URLSAFE = 
    [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
     -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, -1, 
     52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1, 0, -1, -1, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 
     9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1, -1, -1, -1, 63, -1, 26, 
     27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 
     51, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
     -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
     -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
     -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
     -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
     -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1] 


  # Generic base 64 encoding 
  # Derived from 
  # http://www.java2s.com/Code/Java/Development-Class/AfastandmemoryefficientclasstoencodeanddecodetoandfromBASE64infullaccordancewithRFC2045.htm)
  def self._encode64(bin, line_sep, base64_chars)
    arg bin: :String, base64_chars: :String
    local str: :String
    result :String
    
    # Check special case
    return "" if bin.empty?
    slen = bin.length

    # Number of even 24 bits (groups of 3 bytes)
    elen = (slen / 3) * 3
    # Encoded character count
    ccnt = ((slen - 1) / 3 + 1) << 2
    # Size of encoded string (incl. line separators)
    # Note : Ruby implementation always add a \n at the end
    # hence the +1
    dlen = ccnt
    dlen += ((ccnt - 1) / 60 + 1) * LINE_SEP.length if line_sep

    # Allocate the proper size for encoded string
    # to avoid allocating many string objects during
    # concatenation
    str = String.new(0, dlen)

    # Encode even 24 bits
    s=0; d=0; cc=0
    while s < elen
      # Copy next three bytes into lower 24 bits of int, 
      # paying attention to sign.
      i = bin[s].ord << 16  | bin[s+1].ord << 8 | bin[s+2].ord
      s += 3

      # Encode the int into four chars
      str[d] = base64_chars[(i >> 18) & 0x3f]; d += 1
      str[d] = base64_chars[(i >> 12) & 0x3f]; d += 1
      str[d] = base64_chars[(i >> 6) & 0x3f]; d += 1
      str[d] = base64_chars[i & 0x3f]; d += 1
      cc += 1

      # Add optional line separator each 60 chars in Ruby
      if (line_sep && cc == 15 && d < dlen - 1)
        str[d] = LINE_SEP; d += LINE_SEP.length
        cc = 0
      end
    end

    # Pad and encode last bits if source isn't even 24 bits.
    left = slen - elen # 0 - 2
    if left > 0
      # Prepare the last int
      i = bin[elen].ord << 10
      i |= (bin[slen - 1].ord << 2) if left == 2

      # Set last four chars
      str[d] = base64_chars[i >> 12]; d += 1
      str[d] = base64_chars[(i >> 6) & 0x3f]; d += 1
      if left == 2
        str[d] = base64_chars[i & 0x3f]
      else
        str[d] = PAD
      end
      d += 1
      str[d] = PAD; d += 1
    end

    str[d] = LINE_SEP if line_sep
    return str
  end


  # Decodes a BASE64 encoded String. All illegal characters will be 
  # ignored and can handle both arrays with and without line separators.
  # 
  # Derived from
  # http://www.java2s.com/Code/Java/Development-Class/AfastandmemoryefficientclasstoencodeanddecodetoandfromBASE64infullaccordancewithRFC2045.htm)

  def self._decode64(str, base64_chars, base64_char_map)
    arg str: :String, base64_chars: :String, base64_char_map: :Array32
    local bin: :String
    result :String

    # Check special case
    return "" if (slen = str.length) == 0
  
    # Count illegal characters (including '\r', '\n') to know what
    # size the returned array will be, so we don't have to reallocate
    # & copy it later.
    # Number of separator characters. (Actually illegal characters, 
    # but that's a bonus...)
    sepcnt = 0; i = 0
    while  i < slen
      sepcnt += 1 if base64_char_map[str[i].ord] < 0
      i += 1
    end

    # Check that legal chars (including '=') are evenly divideable
    # by 4 as specified in RFC 2045.
    return "" if (slen - sepcnt) % 4 != 0

    # Count padding chars from the end
    pad = 0; i = slen-1
    while i > 0 && base64_char_map[str[i].ord] <= 0
      pad += 1 if str[i] == PAD
      i -= 1
    end

    # Preallocate String of exact length
    len = ((slen - sepcnt) * 6 >> 3) - pad
    bin = String.new(0, len)

    # Go on decoding
    s = 0; d = 0
    while d < len
      # Assemble 3 bytes into an int from 4 valid characters.
      i = 0; j = 0
      while j < 4
        c = base64_char_map[str[s].ord]; s += 1
        # j increases only if a valid char is found
        if c != -1
          i |= c << (18 - j * 6)
          j += 1
        end
      end

      # Now decode the int and add 3 chars to the bin string
      bin[d] = (i >> 16 & 0xff).chr; d += 1
      if d < len
        bin[d] = (i >> 8 & 0xff).chr; d += 1
        if d < len
          bin[d] = (i & 0xff).chr; d += 1
        end
      end
    end

    return bin
  end

  def self.decode64(str)
    arg str: :String
    result :String
    self._decode64(str, BASE64_CHARS, BASE64_CHAR_MAP)
  end

  def self.encode64(bin)
    arg bin: :String
    result :String
    self._encode64(bin, 1, BASE64_CHARS)
  end

  def self.strict_decode64(str)
    arg str: :String
    self._decode64(str, BASE64_CHARS, BASE64_CHAR_MAP)
  end

  def self.strict_encode64(bin)
    arg bin: :String
    result :String
    self._encode64(bin, 0, BASE64_CHARS)
  end

  def self.urlsafe_decode64(str)
    arg str: :String
    self._decode64(str, BASE64_CHARS_URLSAFE, BASE64_CHAR_MAP_URLSAFE)
  end

  def self.urlsafe_encode64(bin)
    arg bin: :String
    result :String
    self._encode64(bin, 0, BASE64_CHARS_URLSAFE)
  end

end