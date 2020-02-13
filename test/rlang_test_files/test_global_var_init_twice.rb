$MYGLOB = 1

class Test
  export
  def self.test_global_var_init_twice
    $MYGLOB = 2
  end
end