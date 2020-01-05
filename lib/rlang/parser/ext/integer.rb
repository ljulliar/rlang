class Integer
  def to_little_endian(byte_count)
    ("%0#{byte_count*2}X" % self).scan(/../).reverse.map {|byte| "\\#{byte}"}.join('')
  end
end