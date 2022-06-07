require 'rlang_core'

class Test
  export
  def self.test_string_index_assign_long_string
    result :String
    stg = String.new(0,256)
    i = 0
    while i < 256
      stg[i] = i.chr
      i += 1
    end
    stg
  end
end