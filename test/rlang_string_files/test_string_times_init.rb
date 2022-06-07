require 'rlang_core'

class Test
  export
  def self.test_string_times_init
    result :String
    "ABCD" * 35
  end
end