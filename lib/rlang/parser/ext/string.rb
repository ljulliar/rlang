class String
  def to_wasm
    self.split('').map {|c| (32..126).include?(c.ord) ? c : "\\#{'%02X' % c.ord}"}.join('')
  end
end