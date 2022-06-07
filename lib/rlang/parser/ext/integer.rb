class Integer
  # Works for both signed and unsignd 32 or 64 bits integers
  def to_little_endian(byte_count)
    i = (self < 0) ? 2**(byte_count*8) + self : self
    ("%0#{byte_count*2}X" % i).scan(/../).reverse.map {|byte| "\\#{byte}"}.join('')
  end
end