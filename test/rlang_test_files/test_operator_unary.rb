require 'rlang_core'

class Test
  export
  def self.test_unary_minus(arg); -arg; end

  export
  def self.test_unary_not(arg); !arg;  end
end