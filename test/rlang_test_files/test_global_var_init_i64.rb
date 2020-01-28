$BIG_NUMBER = 400_000_000_000.to_I64

class Test
  export
  def self.test_global_var_init_i64
    result :I64
    $BIG_NUMBER
  end
end