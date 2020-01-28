class Test
  @@cvar1 = 1000

  export
  def self.test_opasgn_class_var
    @@cvar1 -= 100
  end
end