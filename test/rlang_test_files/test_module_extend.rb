module M
  def add(a,b)
    a + b
  end

  def other(a,b)
    a * b
  end
end

class Test
  extend M

  # This method has priority over M#add
  def self.other(a,b)
    1000 + a + b
  end

  export
  def self.test_module_extend
    Test.add(3,10) + Test.other(5, 20)
  end
end