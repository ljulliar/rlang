# Use a number beyond the limits of an F32 (more than 7 digit
# precision and an exponential part above 38)
$BIG_NUMBER = 3.1234567891011e124.to_F64

class Test
  export
  def self.test_global_var_init_f64
    result :F64
    $BIG_NUMBER
  end
end