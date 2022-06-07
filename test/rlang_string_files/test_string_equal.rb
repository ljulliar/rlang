require 'rlang_core'

class Test
  STRING = "ABCDEFGHIKL"
  export
  def self.test_string_equal
    result :I32
    STRING == "ABCDEFGHIKL"
  end
end