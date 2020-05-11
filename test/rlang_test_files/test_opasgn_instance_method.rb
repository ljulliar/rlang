require 'rlang_core' 

class Test

  def ptr=(arg)
    @ptr = arg + 10
  end

  def ptr
    @ptr + 20
  end

  def initialize(arg)
    @ptr = arg
  end

  export
  def self.test_opasgn_instance_method
    t = self.new(90)
    #t.ptr *= 10 # 1110
    t.ptr=(t.ptr * 10)
  end
end