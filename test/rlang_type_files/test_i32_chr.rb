require 'rlang_core'

class Test
  export
  def self.test_i32_chr(n)
    result :String
    n.chr
  end
end