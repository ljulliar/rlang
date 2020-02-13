require 'rlang/lib'

class Test

  wattr :x, :y
  # This allocate a new Test structure and assign 
  # the pointer to that structure to @@cvar
  @@cvar = self.new

  export
  def self.test_wattr_definition(arg)
    @@cvar.x = arg - 1
    @@cvar.y = 10000
    return @@cvar.x + @@cvar.y
  end
end