class Test
  # explicitely cast result as i64
  export
  def self.test_def_return_i64
    result :I64
    return (3 * 7).to_i64
  end
end