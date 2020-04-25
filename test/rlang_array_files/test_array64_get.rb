require 'rlang/lib'

class Test

  export
  def self.test_array64_set
    @@arr = Array64.new(20)
    i = 0
    while i < 20
      @@arr[i] = 10_000_000_000.to_I64*i
      i += 1
    end
    @@arr
  end

  export
  def self.test_array64_get(idx)
   @@arr[idx] == 10_000_000_000.to_I64*idx
  end
end