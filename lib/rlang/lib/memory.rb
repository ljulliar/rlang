class Memory

  def self.size
    inline wat: '(memory.size)'
  end

  def self.grow(delta)
    inline wat: '(memory.grow (local.get $delta))'
  end
  
end