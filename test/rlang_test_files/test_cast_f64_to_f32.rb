class Test
  export
  def self.test_cast_f64_to_f32
    result :F32
    local double_float: :F64
    double_float = 1.234567890123456e8
    double_float.to_F32
  end
end