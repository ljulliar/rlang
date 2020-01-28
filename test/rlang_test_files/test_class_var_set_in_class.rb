class Test
  @@cvar1 = 2000

  export
  def self.test_class_var_set_in_class
    @@cvar1 / 10
  end
end