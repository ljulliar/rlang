require 'rlang_core'

class Square
  attr_accessor :side
end

class Test
  @@cvar = Square.new

  export
  def self.test_opasgn_setter(arg1)
    local n: :I32
    p = @@cvar; n = 2
    p.side = arg1
    p.side -= n
  end
end