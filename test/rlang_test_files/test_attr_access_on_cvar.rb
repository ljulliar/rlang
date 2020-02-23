require 'rlang/lib'

class Test

  attr_accessor :x, :y
  # This allocate a new Test structure and assign 
  # the pointer to that structure to @@cvar
  @@cvar = self.new

  export
  def self.test_attr_access_on_cvar(arg)
    @@cvar.x = arg - 1
    @@cvar.y = 10000
    return @@cvar.x + @@cvar.y
  end
end