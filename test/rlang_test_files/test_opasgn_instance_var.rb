# Dynamic allocator needed
require 'rlang/lib' 

class Test
  def initialize(arg)
    @ivar = arg
  end

  def times_ten
    @ivar *= 10
  end

  export
  def self.test_opasgn_instance_var
    t = self.new(90)
    t.times_ten
  end
end