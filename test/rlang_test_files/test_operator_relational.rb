require 'rlang_core'

class Test

  export
  def self.test_binary_eq(arg1, arg2); arg1==arg2; end
  export
  def self.test_binary_ne(arg1, arg2); arg1!=arg2; end
  export
  def self.test_binary_lt_u(arg1, arg2); arg1<arg2; end
  export
  def self.test_binary_gt_u(arg1, arg2); arg1>arg2; end
  export
  def self.test_binary_le_u(arg1, arg2); arg1<=arg2; end
  export
  def self.test_binary_ge_u(arg1, arg2); arg1>=arg2; end

end