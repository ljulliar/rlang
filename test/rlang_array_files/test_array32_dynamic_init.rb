require 'rlang/lib'

class Test
  export
  def self.test_array32_dynamic_init
    arr = Array32.new(20)
    arr.size * 100 + arr.count * 10 + arr.length
  end
end