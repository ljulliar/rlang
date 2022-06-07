require 'rlang_core'

class Test
  STRING = "ABCDEFGHIKL"
  export
  def self.test_string_equal_not_op
    result :I32
    STRING != "ABCD1234567"
  end
end