require 'rlang_core'

class Test
  export
  def self.test_string_index_assign
    result :String
    stg = "azerty__"
    stg[-8] = "A"  # single char assignment with negative index
    stg[1] = "Z"  # single char assignment
    stg[3] = "RT" # multi char assignment
    stg[5] = "1234" # # multi char assignment with cropping
    stg
  end
end