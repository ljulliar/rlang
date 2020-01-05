class Test
  export
  def self.test_cast_i32_to_i64_signed
    result :I64
    (1+2).to_i64(true)
  end
end