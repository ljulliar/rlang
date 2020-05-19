require 'rlang_core'

class Test
  export
  def self.test_unary_plus(arg1, arg2); arg1+arg2; end

  export
  def self.test_unary_minus(arg1, arg2); arg1-arg2; end

  export
  def self.test_unary_multiply(arg1, arg2); arg1*arg2; end

  export
  def self.test_unary_divide(arg1, arg2); arg1/arg2; end

  export
  def self.test_unary_modulo(arg1, arg2); arg1%arg2; end

  export
  def self.test_unary_and(arg1, arg2); arg1&arg2; end

  export
  def self.test_unary_or(arg1, arg2); arg1|arg2; end

  export
  def self.test_unary_xor(arg1, arg2); arg1^arg2; end

  export
  def self.test_unary_shiftr(arg1, arg2); arg1>>arg2; end

  export
  def self.test_unary_shiftl(arg1, arg2); arg1<<arg2; end
end