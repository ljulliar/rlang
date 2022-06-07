require 'rlang_core'

class Test
  STRING = "ABCDEFGHIKL"
  export
  def self.test_string_equal_not
    result :I32
    r1 = (STRING == "ABCDEF") # different length
    r2 = (STRING == "ABCDEFGHIKl") # same length, last char different
    !r1 & !r2
  end
end