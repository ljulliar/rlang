require 'rlang_core'

class Test

  attr_accessor :x, :y

  export
  def self.test_attr_access_on_lvar(arg)
    t = Test.new
    t.x = arg - 1
    t.y = 10000
    return t.x + t.y
  end
end