require 'rlang/lib'

class Test
  def initialize
    @ivar = 100
  end

  # do not use attr on purpose
  def read_ivar
    @ivar
  end

  export
  def self.test_instance_var_init
    t = Test.new
    t.read_ivar
  end
end