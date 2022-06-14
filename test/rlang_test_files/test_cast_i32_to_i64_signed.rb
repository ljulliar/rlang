class Test
  export
  def self.test_cast_i32_to_i64_signed
    result :I64
    # By default 1+2 is stored as a I32
    (1+2).to_I64
  end
end