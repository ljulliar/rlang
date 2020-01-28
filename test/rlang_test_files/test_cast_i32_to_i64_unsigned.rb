class Test
  export
  def self.test_cast_i32_to_i64_unsigned
    result :I64
    (1+2).to_I64(false)
  end  
end