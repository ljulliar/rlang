class Test
  export
  def self.test_cast_i32_to_i64_unsigned
    result :UI64
    # By default 1+2 is stored as a I32
    (1+2).to_UI64
  end  
end