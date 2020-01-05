class TestA
  def self.test_arg_add(arg1)
    arg1 = arg1 + 15
  end
end

class Test
  export
  def self.test_call_other_class_method(arg1)
    local1 = TestA.test_arg_add(arg1)
  end 
end