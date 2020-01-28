$DEBUG = 0

class Test
  export
  def self.test_opasgn_global_var
    $DEBUG += 1
  end
end