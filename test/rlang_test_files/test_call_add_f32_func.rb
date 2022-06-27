class Test

  # declare result type of this method
  # ahead of time as it is defined after
  # it's used by first method
  result :Test, :test_def_return_f32, :F32

  # 10 should be automatically cast to i64
  export
  def self.test_call_add_f32_func
    result :F32
    1000000 + self.test_def_return_f32
  end

  # explicitely cast result as i64
  def self.test_def_return_f32
    result :F32
    (30000 + 7500).cast_to(:F32)
  end
end