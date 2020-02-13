require 'rlang/lib'

class Test
  # Force first init with i64 value
  def initialize(arg)
    result :I64
    @ivar = arg.to_I64
  end

  def reassign(arg)
    arg arg: :I32
    result :I64
    # as ivar was initialized as I64
    # the statement below should 
    # automatically cast arg from I32 to I64
    @ivar = arg
  end

  export
  def self.test_cast_instance_var
    result :I64
    t = Test.new(1_000)
    t.reassign(5)
  end
end