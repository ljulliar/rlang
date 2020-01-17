class Test
  export
  def self.test_local_var_chained_asgn
    var1 = var2 = var3 = 5
    var1 + 10*var2 + 100*var3
  end
end