$MYGLOB1 = 3

class Test
  $MYGLOB2 = 5
  export
  def self.test_global_var_init
    $MYGLOB3 = 7
    (($MYGLOB1 * 100 + $MYGLOB2) * 100 + $MYGLOB3) * 100
  end
end