class Test
  export
  def self.test_cast_f64_to_i32
    result :I32
    local double_float: :F64
    double_float = -2.1474836012345e7
    double_float.to_I32
  end
end