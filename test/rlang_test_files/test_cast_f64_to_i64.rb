class Test
  export
  def self.test_cast_f64_to_i64
    result :I64
    local simple_float: :F64
    simple_float = 1.2345670123456789e15
    simple_float.to_I64
  end
end