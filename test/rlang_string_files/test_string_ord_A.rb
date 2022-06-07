require 'rlang_core'

class Test
  export
  def self.test_string_ord_A
    result :I32
    "A".ord
  end
end