require 'rlang_core'

class Test
  export
  def self.test_array32_set
    arr = Array32.new(100)
    i = 0
    while i < 100
      arr[i] = 2*i
      i += 1
    end
   arr
  end
end