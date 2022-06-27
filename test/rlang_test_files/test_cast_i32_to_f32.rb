class Test
  export
  def self.test_cast_i32_to_f32
    result :F32
    local simple_int: :I32
    simple_int = -2147483612
    simple_int.to_F32
  end
end