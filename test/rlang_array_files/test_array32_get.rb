require 'rlang_core'

class Test

  export
  def self.test_array32_set(n)
    @@arr = Array32.new(100)
    i = 0
    while i < 100
      @@arr[i] = n*i
      i += 1
    end
    @@arr
  end

  export
  def self.test_array32_get(idx)
   @@arr[idx]
  end
end