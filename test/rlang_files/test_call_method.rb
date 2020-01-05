class Test

  def self.test_def_two_args(arg1, arg2)
    local1 = arg1 * 10
    local2 = arg2 + local1
  end

  export
  def self.test_call_method(arg1)
    self.test_def_two_args(arg1, 200)
  end
end