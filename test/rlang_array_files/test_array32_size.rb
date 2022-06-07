require 'rlang_core'

class Test
  export
  def self.test_array32_size(sz)
    # test both the size attribute and the real
    # size in memory
    arr = Array32.new(sz)
    arr[sz-1] = sz
    arr.size - arr[sz-1]
  end
end