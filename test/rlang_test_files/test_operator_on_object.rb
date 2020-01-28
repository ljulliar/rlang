class Header
  wattr :size, :ptr
  wattr_type size: :I64, ptr: :I32
end

class Test
  # Allocate some data so that 
  # Header is not allocated at 
  # address 0 in memory
  CONST1 = 10
  CONST2 = 100
  @@cvar = Header.new

  export
  def self.base
    @@cvar
  end

  export
  def self.test_operator_on_object
    @@cvar + 5 
  end
end