# Dynamic allocator needed
require 'rlang/lib' 

class Test

  # declare two ivar to make sure 
  # wattr memory offset works 
  def initialize(arg)
    @ivar1 = arg
    @ivar2 = @ivar1 + 50
  end

  def times_ten
    @ivar2 *= 10
  end

  export
  def self.test_opasgn_instance_var
    t = self.new(90)
    t.times_ten
  end
end