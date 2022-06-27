# Use a number below the limits of an F32 (it must naturally
# interpreted as a single precision float with need to cast
# with #to_F32 call
$BIG_NUMBER = 3.14

class Test
  export
  def self.test_global_var_init_f32
    result :F32
    $BIG_NUMBER
  end
end