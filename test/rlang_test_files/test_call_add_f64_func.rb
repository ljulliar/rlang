class Test

  # declare result type of this method
  # ahead of time as it is defined after
  # it's used by first method
  result :Test, :test_def_return_f64, :F64

  # 10 should be automatically cast to i64
  export
  def self.test_call_add_f64_func
    result :F64
    1000000 + self.test_def_return_f64
  end

  # explicitely cast result as i64
  def self.test_def_return_f64
    result :F64
    (30000 + 75000).cast_to(:F64)
  end
end