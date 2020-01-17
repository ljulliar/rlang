class Test
  # local must be declared as i64. If not the expression
  # is type cast to i32
  export
  def self.test_def_one_arg_with_type_and_implicit_type_cast(arg1)
    arg arg1: :I64
    result :I64
    local local1: :I64

    local1 = arg1 * 10
  end
end