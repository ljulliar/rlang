class Test
  export
  def self.test_cast_implicit_i32_to_i64
    result :I64
    local v1: :I64
    v1 = 10
    return v1 + 2147483648 # max 32 bit signed integer + 10
  end
end