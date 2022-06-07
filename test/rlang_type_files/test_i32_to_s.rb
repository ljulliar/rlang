require 'rlang_core'

class Test
  export
  def self.test_i32_to_s(n)
    result :String
    n.to_s
  end
end