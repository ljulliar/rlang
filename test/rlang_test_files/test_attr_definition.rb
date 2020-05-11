require 'rlang_core'

class Test

  attr_accessor :rw
  attr_reader   :r
  attr_writer   :w

  def test_attr_access
    self.rw = 1
    self.w = 10
    @r = 100
    self.rw + @w + self.r
  end

  export
  def self.test_attr_definition
    t = self.new
    t.test_attr_access
  end
end