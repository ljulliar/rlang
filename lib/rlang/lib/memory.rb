require 'rlang/lib/type'

class Memory

  def self.size
    inline wat: '(memory.size)'
  end

  def self.grow(delta)
    inline wat: '(memory.grow (local.get $delta))'
  end

  # Copy memory from source to destination address
  # TODO: optimize this method using 64 bits copy
  # first then 32 bits, then 16, then 8 bits
  def self.copy(src, dest, size)
    arg src: :I32, dest: :I32
    result :none
    idx = 0
    while idx < size
      inline wat: '(i32.store8 
      (i32.add (local.get $dest) (local.get $idx))
      (i32.load8_u (i32.add (local.get $src) (local.get $idx)))
      )', wtype: :none
      idx += 1
    end
  end
  
end