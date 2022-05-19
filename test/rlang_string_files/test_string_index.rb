require 'rlang_core'

class Test
  export
  def self.test_string_index(n)
    result :String
    stg = "azerty"
    stg[n]
  end
end