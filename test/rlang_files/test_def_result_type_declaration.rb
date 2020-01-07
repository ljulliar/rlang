class Test

  # declare Test::test_def_return_i64 method because
  # it's being called **before** it is defined
  result :Test, :test_def_return_i64, :I64

  export
  def self.test_def_result_type_declaration
    result :I64
    self.test_def_return_i64 + 100
  end

  def self.test_def_return_i64
    result :I64
    return (3 * 7).to_i64
  end
end