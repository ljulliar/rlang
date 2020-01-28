class Test

  # call on implicit self
  def instance_m1(arg)
    instance_m2(arg) + 20
  end

  # call on explicit self
  def instance_m2(arg)
    self.instance_m3(arg) * 100
  end

  def instance_m3(arg)
    arg * 10
  end

  # Fake class method to make sure
  # it is not called
  def self.instance_m3(arg)
    arg * 100_000
  end

  @@cvar = Test.new

  export
  def self.test_call_on_self_instance
    @@cvar.instance_m1(5)
  end

end