class Test

  # declare result type of this method
  # ahead of time as it is defined after
  # it's used by first method
  result :Test, :test_def_return_i64, :I64

  # 10 should be automatically cast to i64
  export
  def self.test_call_add_i64_func
    result :I64
    10 + self.test_def_return_i64
  end

  # explicitely cast result as i64
  def self.test_def_return_i64
    result :I64
    (3 + 7).cast_to(:I64)
  end
end