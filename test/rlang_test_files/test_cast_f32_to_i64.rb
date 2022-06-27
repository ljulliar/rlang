class Test
  export
  def self.test_cast_f32_to_i64
    result :I64
    local simple_float: :F32
    simple_float = 1.234567e11
    simple_float.to_I64
  end
end