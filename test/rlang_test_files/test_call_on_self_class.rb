class Test

  # call with implicit self on class
  def self.instance_m1(arg)
    instance_m2(arg) + 20
  end
  
  # call with explicit self on class
  def self.instance_m2(arg)
    self.instance_m3(arg) * 100
  end

  def self.instance_m3(arg)
    arg * 10
  end

  # Fake instance method to make sure
  # it is not called
  def instance_m3(arg)
    arg * 100_000
  end

  export
  def self.test_call_on_self_class
    self.instance_m1(5)
  end

end