class Test
  export
  def self.test_cast_f32_to_i32
    result :I32
    local simple_float: :F32
    simple_float = -2.1474836e7
    simple_float.to_I32
  end
end